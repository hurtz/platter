import Foundation
import Combine

enum DriveArt {
    case floppy35, floppy525, stepper, hdd, server

    var isFloppy: Bool { self == .floppy35 || self == .floppy525 }
}

struct DriveInfo: Identifiable {
    let id: Int
    let name: String
    let era: String
    let detail: String
    let art: DriveArt

    static let all: [DriveInfo] = [
        DriveInfo(id: 0, name: "3.5\u{2033} Floppy", era: "1.44 MB \u{00B7} 1990s", detail: "1.44 MB floppy \u{00B7} 300 RPM", art: .floppy35),
        DriveInfo(id: 1, name: "5.25\u{2033} Floppy", era: "360 KB \u{00B7} 1980s", detail: "360 KB floppy \u{00B7} head solenoid", art: .floppy525),
        DriveInfo(id: 2, name: "Stepper HDD", era: "20 MB MFM \u{00B7} 1986", detail: "20 MB MFM \u{00B7} 3600 RPM stepper", art: .stepper),
        DriveInfo(id: 3, name: "IDE Drive", era: "540 MB \u{00B7} 1995", detail: "540 MB IDE \u{00B7} 5400 RPM", art: .hdd),
        DriveInfo(id: 4, name: "Desktop HDD", era: "7200 RPM \u{00B7} 2005", detail: "250 GB SATA \u{00B7} 7200 RPM", art: .hdd),
        DriveInfo(id: 5, name: "Server 15K", era: "15K RPM \u{00B7} SAS", detail: "146 GB SAS \u{00B7} 15,000 RPM", art: .server),
    ]

    static func info(_ id: Int) -> DriveInfo { all[max(0, min(all.count - 1, id))] }
}

/// User settings, persisted in UserDefaults.
final class AppState: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var isOn: Bool { didSet { defaults.set(isOn, forKey: "isOn") } }
    @Published var profile: Int { didSet { defaults.set(profile, forKey: "profile") } }
    @Published var volume: Double { didSet { defaults.set(volume, forKey: "volume") } }
    @Published var hum: Double { didSet { defaults.set(hum, forKey: "hum") } }
    @Published var mode: Int { didSet { defaults.set(mode, forKey: "mode") } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") } }

    // Live disk throughput of the Mac, bytes per second (not persisted).
    @Published var readRate: Double = 0
    @Published var writeRate: Double = 0

    var isFirstRun: Bool {
        get { defaults.bool(forKey: "firstRun") }
        set { defaults.set(newValue, forKey: "firstRun") }
    }

    init() {
        defaults.register(defaults: [
            "isOn": false,
            "profile": 4,
            "volume": 0.6,
            "hum": 0.7,
            "mode": 0,
            "launchAtLogin": true,
            "firstRun": true,
        ])
        isOn = defaults.bool(forKey: "isOn")
        profile = max(0, min(DriveInfo.all.count - 1, defaults.integer(forKey: "profile")))
        volume = defaults.double(forKey: "volume")
        hum = defaults.double(forKey: "hum")
        mode = max(0, min(2, defaults.integer(forKey: "mode")))
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    var drive: DriveInfo { DriveInfo.info(profile) }

    var rateText: String {
        func fmt(_ v: Double) -> String {
            let mb = v / 1_000_000
            if mb >= 100 { return String(format: "%.0f", mb) }
            if mb >= 10 { return String(format: "%.1f", mb) }
            return String(format: "%.2f", mb)
        }
        return "R \(fmt(readRate))  W \(fmt(writeRate)) MB/s"
    }
}

/// High rate values from the sound engine. Deliberately not @Published:
/// views read it inside TimelineView so SwiftUI is not invalidated 30 times a second.
final class Telemetry: ObservableObject {
    var spin: Double = 0
    var head: Double = -0.08
    var readLevel: Double = 0
    var writeLevel: Double = 0
    var ready = false
    var power = false
    var engineRunning = false

    private var angle: Double = 0
    private var shownHead: Double = -0.08
    private var lastDate: Date?

    struct Frame {
        var angle: Double
        var head: Double
        var spin: Double
        var read: Double
        var write: Double
        var power: Bool
    }

    func frame(at date: Date, floppy: Bool) -> Frame {
        let dt = min(0.1, max(0, date.timeIntervalSince(lastDate ?? date)))
        lastDate = date
        // Visual rotation speed (kept slow enough to avoid wagon wheel effects).
        let revsPerSecond = floppy ? 0.9 : 1.6
        angle += spin * revsPerSecond * 2 * .pi * dt
        if angle > 2 * .pi * 1000 { angle -= 2 * .pi * 1000 }
        let k = 1 - exp(-dt * 22)
        shownHead += (head - shownHead) * k
        return Frame(angle: angle, head: shownHead, spin: spin, read: readLevel, write: writeLevel, power: power)
    }

    func statusText(isOn: Bool, floppy: Bool) -> String {
        if !isOn {
            if engineRunning && spin > 0.02 { return floppy ? "STOPPING" : "SPINNING DOWN" }
            return "OFF"
        }
        if writeLevel > 0.05 { return "WRITING" }
        if readLevel > 0.05 { return "READING" }
        if floppy { return ready ? (spin > 0.05 ? "MOTOR ON" : "READY") : "CHECKING" }
        if !ready { return spin < 0.97 ? "SPINNING UP" : "CALIBRATING" }
        return "IDLE"
    }
}
