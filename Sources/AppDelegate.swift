import AppKit
import SwiftUI
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    let telemetry = Telemetry()
    private var audio: AudioController!
    private let monitor = DiskMonitor()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var iconKey = ""
    private var rateR = 0.0, rateW = 0.0, rateTick = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        audio = AudioController()
        let synth = audio.synth

        ds_set_profile(synth, Int32(state.profile))
        ds_set_mode(synth, Int32(state.mode))
        ds_set_volume(synth, Float(state.volume))
        ds_set_hum(synth, Float(state.hum))

        monitor.onDelta = { [weak self] d, dt in
            ds_post_activity(synth, d.readOps, d.writeOps, d.readBytes, d.writeBytes)
            self?.updateRates(d, dt)
        }

        setupStatusItem()
        setupPopover()
        bindState()
        syncLoginItem()

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)

        if state.isOn { powerChanged(true) }
        refreshIcon(force: true)

        if state.isFirstRun {
            state.isFirstRun = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.showPopover() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        audio?.stop()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.toolTip = "Platter \u{2014} click for options, right-click to switch on or off"
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isRight {
            state.isOn.toggle()
        } else if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func setupPopover() {
        let root = PanelView()
            .environmentObject(state)
            .environmentObject(telemetry)
        let host = NSHostingController(rootView: root)
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func refreshIcon(force: Bool = false) {
        guard let button = statusItem?.button else { return }
        let r = (telemetry.readLevel * 5).rounded() / 5
        let w = (telemetry.writeLevel * 5).rounded() / 5
        let art = state.drive.art
        let key = "\(art)-\(state.isOn)-\(r)-\(w)"
        if !force && key == iconKey { return }
        iconKey = key
        button.image = StatusIcon.make(art: art, power: state.isOn, read: r, write: w)
    }

    // MARK: - State

    private func bindState() {
        let synth = audio.synth
        state.$isOn.dropFirst().removeDuplicates().sink { [weak self] on in
            self?.powerChanged(on)
        }.store(in: &cancellables)
        state.$profile.dropFirst().removeDuplicates().sink { [weak self] p in
            ds_set_profile(synth, Int32(p))
            DispatchQueue.main.async { self?.refreshIcon(force: true) }
        }.store(in: &cancellables)
        state.$mode.dropFirst().sink { ds_set_mode(synth, Int32($0)) }.store(in: &cancellables)
        state.$volume.dropFirst().sink { ds_set_volume(synth, Float($0)) }.store(in: &cancellables)
        state.$hum.dropFirst().sink { ds_set_hum(synth, Float($0)) }.store(in: &cancellables)
        state.$launchAtLogin.dropFirst().removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.syncLoginItem() }
        }.store(in: &cancellables)
    }

    private func powerChanged(_ on: Bool) {
        let synth = audio.synth
        if on {
            audio.start()
            ds_set_power(synth, 1)
            monitor.start()
            startPolling()
        } else {
            ds_set_power(synth, 0)
            monitor.stop()
            rateR = 0; rateW = 0
            state.readRate = 0; state.writeRate = 0
            // keep polling: the engine shuts down once the drive has spun down
            startPolling()
        }
        DispatchQueue.main.async { self.refreshIcon(force: true) }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = 0.005
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func poll() {
        var st = DSStatus()
        ds_get_status(audio.synth, &st)
        telemetry.spin = Double(st.spin)
        telemetry.head = Double(st.headPos)
        telemetry.ready = st.ready != 0
        telemetry.power = st.power != 0
        telemetry.engineRunning = audio.isRunning
        telemetry.readLevel = st.readLED > 0 ? 0.6 + 0.4 * Double(st.readLED) : (telemetry.readLevel < 0.05 ? 0 : telemetry.readLevel * 0.3)
        telemetry.writeLevel = st.writeLED > 0 ? 0.6 + 0.4 * Double(st.writeLED) : (telemetry.writeLevel < 0.05 ? 0 : telemetry.writeLevel * 0.3)
        refreshIcon()

        if !state.isOn && st.silent != 0 {
            audio.stop()
            telemetry.engineRunning = false
            telemetry.readLevel = 0
            telemetry.writeLevel = 0
            stopPolling()
            refreshIcon(force: true)
        }
    }

    private func updateRates(_ d: DiskMonitor.Totals, _ dt: TimeInterval) {
        let k = 0.25
        rateR += (Double(d.readBytes) / dt - rateR) * k
        rateW += (Double(d.writeBytes) / dt - rateW) * k
        rateTick += 1
        if rateTick % 5 == 0 {
            state.readRate = rateR
            state.writeRate = rateW
        }
    }

    @objc private func didWake() {
        guard state.isOn else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.audio.restartIfNeeded()
        }
    }

    // MARK: - Login item

    private func syncLoginItem() {
        let service = SMAppService.mainApp
        do {
            if state.launchAtLogin {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("Platter: login item update failed: \(error)")
        }
    }
}
