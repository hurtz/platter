import AVFoundation
import IOKit

/// Hosts the C sound engine inside an AVAudioEngine source node.
final class AudioController {
    let synth: OpaquePointer
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode!
    private var wantsRunning = false
    static let sampleRate: Double = 48_000

    init() {
        guard let s = ds_create(AudioController.sampleRate, UInt32.random(in: 1...UInt32.max)) else {
            fatalError("Could not create sound engine")
        }
        synth = s
        let format = AVAudioFormat(standardFormatWithSampleRate: AudioController.sampleRate, channels: 1)!
        let synthRef = s
        source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard buffers.count > 0, let first = buffers[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            ds_render(synthRef, first, Int32(frameCount))
            if buffers.count > 1 {
                for i in 1..<buffers.count {
                    if let dst = buffers[i].mData {
                        memcpy(dst, first, Int(frameCount) * MemoryLayout<Float>.size)
                    }
                }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0

        NotificationCenter.default.addObserver(
            self, selector: #selector(configurationChanged(_:)),
            name: .AVAudioEngineConfigurationChange, object: engine)
    }

    var isRunning: Bool { engine.isRunning }

    func start() {
        wantsRunning = true
        guard !engine.isRunning else { return }
        engine.prepare()
        do { try engine.start() } catch { NSLog("Platter: audio engine failed to start: \(error)") }
    }

    func stop() {
        wantsRunning = false
        if engine.isRunning { engine.stop() }
    }

    /// Restart after sleep or an output device change.
    func restartIfNeeded() {
        guard wantsRunning else { return }
        if engine.isRunning { engine.stop() }
        engine.prepare()
        do { try engine.start() } catch { NSLog("Platter: audio engine restart failed: \(error)") }
    }

    @objc private func configurationChanged(_ note: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.restartIfNeeded()
        }
    }
}

/// Polls the I/O statistics of every block storage device (what Activity Monitor shows).
final class DiskMonitor {
    struct Totals { var readOps: UInt64 = 0, writeOps: UInt64 = 0, readBytes: UInt64 = 0, writeBytes: UInt64 = 0 }

    var onDelta: ((Totals, TimeInterval) -> Void)?
    private var timer: Timer?
    private var last: Totals?
    private var lastTime = Date()

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        last = DiskMonitor.readTotals()
        lastTime = Date()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.02
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        last = nil
    }

    private func tick() {
        let now = DiskMonitor.readTotals()
        let time = Date()
        defer { last = now; lastTime = time }
        guard let prev = last else { return }
        func d(_ a: UInt64, _ b: UInt64) -> UInt64 { a >= b ? a - b : 0 }
        var delta = Totals()
        delta.readOps = d(now.readOps, prev.readOps)
        delta.writeOps = d(now.writeOps, prev.writeOps)
        delta.readBytes = d(now.readBytes, prev.readBytes)
        delta.writeBytes = d(now.writeBytes, prev.writeBytes)
        // Ignore absurd jumps (a device was attached or detached).
        if delta.readOps > 1_000_000 || delta.writeOps > 1_000_000 { return }
        onDelta?(delta, max(0.01, time.timeIntervalSince(lastTime)))
    }

    static func readTotals() -> Totals {
        var totals = Totals()
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOBlockStorageDriver"),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return totals
        }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let value = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue(),
               let stats = value as? [String: Any] {
                func num(_ key: String) -> UInt64 { (stats[key] as? NSNumber)?.uint64Value ?? 0 }
                totals.readOps &+= num("Operations (Read)")
                totals.writeOps &+= num("Operations (Write)")
                totals.readBytes &+= num("Bytes (Read)")
                totals.writeBytes &+= num("Bytes (Write)")
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return totals
    }
}
