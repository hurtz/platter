import SwiftUI
import AppKit

extension Color {
    static let ledGreen = Color(red: 0.20, green: 0.92, blue: 0.42)
    static let ledAmber = Color(red: 1.00, green: 0.66, blue: 0.10)
}

struct PanelView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 10) {
            HeroCard()
            SectionLabel(title: "Drive")
            DrivePicker()
            SectionLabel(title: "Sound")
            ControlsCard()
            FooterBar()
        }
        .padding(14)
        .frame(width: 352)
    }
}

struct SectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.top, 2)
    }
}

// MARK: - Hero

struct HeroCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let drive = state.drive
        HStack(alignment: .center, spacing: 14) {
            DriveStage(art: drive.art)
                .frame(width: 116, height: 116)
                .id(drive.id)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("PLATTER")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(2.6)
                        .foregroundColor(.white.opacity(0.42))
                    Spacer(minLength: 4)
                    PowerSwitch(isOn: $state.isOn)
                }
                Spacer(minLength: 6)
                Text(drive.name)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(drive.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                LEDStrip()
            }
            .frame(height: 116)
        }
        .padding(12)
        .background(HeroBackground())
    }
}

struct HeroBackground: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(red: 0.17, green: 0.18, blue: 0.20),
                                          Color(red: 0.07, green: 0.075, blue: 0.085)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.03)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: .black.opacity(0.28), radius: 9, x: 0, y: 4)
    }
}

struct LEDStrip: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var telemetry: Telemetry

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            HStack(spacing: 8) {
                LEDLight(color: .ledGreen, level: telemetry.readLevel)
                    .help("Read activity")
                LEDLight(color: .ledAmber, level: telemetry.writeLevel)
                    .help("Write activity")
                Spacer(minLength: 6)
                Text(telemetry.statusText(isOn: state.isOn, floppy: state.drive.art.isFloppy))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

struct LEDLight: View {
    let color: Color
    let level: Double

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.65)).frame(width: 11, height: 11)
            Circle().fill(color.opacity(0.16 + 0.84 * level)).frame(width: 8, height: 8)
            Circle().fill(Color.white.opacity(0.55 * level)).frame(width: 2.8, height: 2.8).offset(x: -1, y: -1)
        }
        .shadow(color: color.opacity(0.9 * level), radius: 5 * level)
        .fixedSize()
    }
}

struct PowerSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { isOn.toggle() }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn
                          ? LinearGradient(colors: [Color(red: 0.27, green: 0.88, blue: 0.47), Color(red: 0.10, green: 0.62, blue: 0.30)], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color(white: 0.30), Color(white: 0.21)], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(isOn ? 0.28 : 0.10), lineWidth: 1))
                    .frame(width: 54, height: 30)
                    .shadow(color: isOn ? Color.green.opacity(0.45) : .clear, radius: 8)
                Circle()
                    .fill(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                    .overlay(
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isOn ? Color(red: 0.10, green: 0.58, blue: 0.28) : Color(white: 0.55))
                    )
                    .padding(2)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Switch the drive off" : "Switch the drive on")
        .accessibilityLabel("Power")
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Drive picker

struct DrivePicker: View {
    @EnvironmentObject var state: AppState
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(DriveInfo.all) { d in
                DriveCard(info: d, selected: state.profile == d.id) {
                    withAnimation(.easeOut(duration: 0.15)) { state.profile = d.id }
                }
            }
        }
    }
}

struct DriveCard: View {
    let info: DriveInfo
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        Button(action: action) {
            HStack(spacing: 9) {
                MiniDriveIcon(art: info.art, selected: selected)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(info.era)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(shape.fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(hovering ? 0.085 : 0.045)))
            .overlay(shape.strokeBorder(selected ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(info.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Controls

struct ControlsCard: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                    .frame(width: 18)
                Text("Activity")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("Activity", selection: $state.mode) {
                    Text("Live").tag(0)
                    Text("Ambient").tag(1)
                    Text("Busy").tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 192)
            }
            Text(caption)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().opacity(0.6)
            SliderRow(symbol: "speaker.wave.2.fill", title: "Volume", value: $state.volume)
            SliderRow(symbol: "wind", title: "Motor hum", value: $state.hum)
        }
        .padding(12)
        .background(shape.fill(Color.primary.opacity(0.045)))
        .overlay(shape.strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
    }

    private var caption: String {
        switch state.mode {
        case 1: return "Simulates an idle computer: the odd read and a write flush now and then."
        case 2: return "Simulates a heavy workload, like copying files or installing software."
        default: return "Follows your Mac\u{2019}s real disk reads and writes as they happen."
        }
    }
}

struct SliderRow: View {
    let symbol: String
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12))
                .frame(width: 72, alignment: .leading)
            Slider(value: $value, in: 0...1)
                .controlSize(.small)
        }
    }
}

// MARK: - Footer

struct FooterBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Toggle("Open at login", isOn: $state.launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .fixedSize()
                Spacer(minLength: 4)
                if state.isOn && state.mode == 0 {
                    Text(state.rateText)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                        .help("Your Mac\u{2019}s real disk throughput")
                }
            }
            HStack(spacing: 4) {
                Text("Platter \(AppInfo.version) \u{00B7} by")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .fixedSize()
                Link("Jason O\u{2019}Connell", destination: AppInfo.authorURL)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .help(AppInfo.authorURL.absoluteString)
                Spacer(minLength: 4)
                Link("GitHub", destination: AppInfo.repoURL)
                    .font(.system(size: 11))
                    .help("Source code, updates and ideas")
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .padding(.leading, 6)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
}

enum AppInfo {
    static let authorURL = URL(string: "https://github.com/hurtz")!
    static let repoURL = URL(string: "https://github.com/hurtz/platter")!
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
