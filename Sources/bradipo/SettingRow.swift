import BradipoCore
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// The control for one setting, labeled with the words the catalog gives it.
struct SettingRow: View {
    let setting: Setting
    let host: SettingsHost

    var body: some View {
        switch setting {
        case .workInterval:
            DurationPicker(setting: setting, key: DefaultsKey.workSeconds,
                           presets: [5, 10, 20, 30, 45, 60].map { $0 * 60 }, apply: host.apply)
        case .shortBreakLength:
            DurationPicker(setting: setting, key: DefaultsKey.breakSeconds, presets: [20, 30, 60, 120, 300],
                           apply: host.apply)
        case .longBreaks:
            SavedToggle(setting: setting, key: DefaultsKey.longBreaksEnabled, apply: host.apply)
        case .longBreakLength:
            LongBreakRow {
                DurationPicker(setting: setting, key: DefaultsKey.longBreakSeconds,
                               presets: [5, 10, 15, 20, 30].map { $0 * 60 }, apply: host.apply)
            }
        case .longBreakFrequency:
            LongBreakRow { ShortBreakCount(apply: host.apply) }
        case .showBanner:
            SavedToggle(setting: setting, key: DefaultsKey.showBreakBanner, apply: host.apply)
        case .bannerPlacement:
            BannerReset(host: host)
        case .accentColor:
            AccentPicker()
        case .glowIntensity:
            GlowSlider(overlay: host.overlay)
        case .screenSharing:
            SavedToggle(setting: setting, key: DefaultsKey.showBreaksInScreenSharing, apply: host.apply)
        case .startSound:
            SavedToggle(setting: setting, key: DefaultsKey.breakStartSound, apply: host.apply)
        case .endSound:
            SavedToggle(setting: setting, key: DefaultsKey.breakEndSound, apply: host.apply)
        case .deferDuringMeetings:
            SavedToggle(setting: setting, key: DefaultsKey.deferBreaksDuringMeetings, apply: host.apply)
        case .ignoredApps:
            IgnoredApps(ignored: host.ignoredApps)
        case .launchAtLogin:
            LoginToggle(login: host.login)
        case .version:
            LabeledContent { Text(About.version) } label: { RowLabel(setting) }
        case .updates:
            LabeledContent {
                Button(host.updater.progress ?? "Check for Updates…") { host.updater.checkForUpdates() }
                    .disabled(host.updater.progress != nil)
            } label: {
                RowLabel(setting)
            }
        case .sourceCode:
            LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                    Link("github.com/marcoieni/bradipo", destination: About.repository)
                    if let commit = About.commit {
                        HStack(spacing: 4) {
                            Text("Commit")
                            Link(String(commit.prefix(12)), destination: About.repository.appending(path: "commit/\(commit)"))
                        }
                    }
                }
            } label: {
                RowLabel(setting)
            }
        }
    }
}

/// A row's title, with a line of detail under it where there's something to add.
private struct RowLabel: View {
    let title: String
    let detail: String?

    init(title: String, detail: String?) {
        self.title = title
        self.detail = detail
    }

    /// Labels a setting with the catalog's words. A detail given here replaces the catalog's.
    init(_ setting: Setting, detail: String? = nil) {
        self.init(title: setting.title, detail: detail ?? setting.detail)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Fires when the person comes back to a window, having perhaps changed what a row shows from outside it.
@MainActor private let windowFocus = NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)

private enum About {
    static let repository = URL(string: "https://github.com/marcoieni/bradipo")!
    static let commit = Bundle.main.object(forInfoDictionaryKey: "BradipoGitCommit") as? String
    static var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        // Release builds stamp the build number with the version, so only a local build shows both.
        guard let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String, build != version else {
            return version
        }
        return "\(version) (\(build))"
    }
}

/// Greys out a row that only matters while long breaks are on.
private struct LongBreakRow<Content: View>: View {
    @ViewBuilder let content: Content
    @AppStorage(DefaultsKey.longBreaksEnabled) private var longBreaks = false

    var body: some View {
        content.disabled(!longBreaks)
    }
}

private struct SavedToggle: View {
    let setting: Setting
    let apply: () -> Void
    @AppStorage private var isOn: Bool

    init(setting: Setting, key: String, apply: @escaping () -> Void) {
        self.setting = setting
        self.apply = apply
        _isOn = AppStorage(wrappedValue: false, key)
    }

    var body: some View {
        Toggle(isOn: $isOn) { RowLabel(setting) }
            .onChange(of: isOn) { apply() }
    }
}

/// A pop-up of preset lengths that can also take any other length.
private struct DurationPicker: View {
    /// Stands for the item that asks for a length, since no length is negative.
    private static let custom = -1
    let setting: Setting
    let presets: [Int]
    let apply: () -> Void
    @AppStorage private var saved: Int
    private var seconds: Int { ScheduleLimits.seconds(saved) }

    init(setting: Setting, key: String, presets: [Int], apply: @escaping () -> Void) {
        self.setting = setting
        self.presets = presets
        self.apply = apply
        _saved = AppStorage(wrappedValue: 0, key)
    }

    var body: some View {
        Picker(selection: Binding { seconds } set: { $0 == Self.custom ? editCustom() : save($0) }) {
            ForEach(presets, id: \.self) { value in
                Text(value.isMultiple(of: 60) ? "\(value / 60) min" : "\(value) sec").tag(value)
            }
            Divider()
            if !presets.contains(seconds) {
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60)).tag(seconds)
            }
            Text("Custom…").tag(Self.custom)
        } label: {
            RowLabel(setting)
        }
    }

    private func save(_ value: Int) {
        saved = value
        apply()
    }

    private func editCustom() {
        // The pop-up is still closing. The default mode waits for it, and a modal alert run by a task
        // would block the main queue, which delivers sleep and microphone changes.
        RunLoop.main.perform {
            MainActor.assumeIsolated {
                if let value = IntervalEditor(title: setting.title, duration: seconds).run() { save(value) }
            }
        }
    }
}

private struct ShortBreakCount: View {
    let apply: () -> Void
    @AppStorage(DefaultsKey.shortBreaksBeforeLongBreak) private var saved = 0

    var body: some View {
        let count = Binding { ScheduleLimits.shortBreaks(saved) } set: { saved = ScheduleLimits.shortBreaks($0) }
        LabeledContent {
            // The field takes any count at once, where the stepper needs a click for each step.
            TextField(Setting.longBreakFrequency.title, value: count, format: .number)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 56)
            Stepper(Setting.longBreakFrequency.title, value: count, in: 1...Int.max).labelsHidden()
        } label: {
            RowLabel(.longBreakFrequency)
        }
        .onChange(of: saved) { apply() }
    }
}

private struct BannerReset: View {
    let host: SettingsHost
    @ViewState private var canReset = false

    var body: some View {
        LabeledContent {
            Button("Reset on All Displays", action: host.overlay.resetBanners)
                .disabled(!canReset)
        } label: {
            RowLabel(.bannerPlacement)
        }
        .onAppear(perform: refresh)
        // A banner can be dragged during a break while this window stays in front.
        .onReceive(NotificationCenter.default.publisher(for: .bannerPlacementChanged)) { _ in refresh() }
    }

    private func refresh() {
        canReset = host.canResetBanners()
    }
}

private struct AccentPicker: View {
    @AppStorage(BreakAccent.defaultsKey) private var accent = BreakAccent.green

    var body: some View {
        LabeledContent {
            Button("Restore Default Green") { accent = .green }
                .disabled(accent == .green)
            ColorPicker(Setting.accentColor.title, selection: Binding { accent.glow } set: { color in
                if let color = BreakAccent(color: NSColor(color)) { accent = color }
            }, supportsOpacity: false)
            .labelsHidden()
        } label: {
            RowLabel(.accentColor)
        }
    }
}

private struct GlowSlider: View {
    let overlay: BreakOverlay

    var body: some View {
        LabeledContent {
            Slider(value: Binding { overlay.intensity.value } set: { overlay.setGlowIntensity($0) }) {
                Text(Setting.glowIntensity.title)
            } onEditingChanged: { dragging in
                overlay.setGlowPreview(dragging)
            }
            .labelsHidden()
            .frame(width: 150)
            Text(overlay.intensity.value, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        } label: {
            RowLabel(.glowIntensity)
        }
    }
}

/// The apps using the microphone now and the ignored ones, each with a switch that ignores it.
private struct IgnoredApps: View {
    @Binding var ignored: [String: String]
    @AppStorage(DefaultsKey.deferBreaksDuringMeetings) private var defersBreaks = false
    @ViewState private var apps = IgnoredAppsSections(recording: [], ignored: [])

    var body: some View {
        rows.disabled(!defersBreaks)
    }

    @ViewBuilder private var rows: some View {
        RowLabel(.ignoredApps)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear(perform: refresh)
            .onReceive(windowFocus) { _ in refresh() }
            .onChange(of: defersBreaks) { refresh() }
        ForEach(apps.recording + apps.ignored, id: \.self) { app in
            Toggle(isOn: Binding { ignored[app.id] != nil } set: { isIgnored in
                ignored[app.id] = isIgnored ? app.name : nil
                refresh()
            }) {
                Label {
                    RowLabel(title: app.name, detail: apps.recording.contains(app) ? "Using the microphone" : nil)
                } icon: {
                    Image(nsImage: app.icon).resizable().frame(width: 18, height: 18)
                }
            }
        }
        if defersBreaks && apps.recording.isEmpty && apps.ignored.isEmpty {
            Text("No apps are using the microphone")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Reading every audio client is costly, so the list is read when it's shown rather than kept current,
    /// and not at all while nothing can be ignored.
    private func refresh() {
        let saved = ignored.map { RecordingApp(id: $0.key, name: $0.value) }
        apps = IgnoredAppsSections(recording: defersBreaks ? MicrophoneMonitor.recordingApps() : [], ignored: saved)
    }
}

private extension RecordingApp {
    var icon: NSImage {
        // An app that isn't installed, or a daemon without an app, gets the generic program icon.
        let path = id.hasPrefix("/") ? id : NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.path
        return path.map(NSWorkspace.shared.icon(forFile:)) ?? NSWorkspace.shared.icon(for: .unixExecutable)
    }
}

private struct LoginToggle: View {
    let login: LoginItem

    var body: some View {
        // When macOS wants the login item approved, turning the switch on opens System Settings.
        Toggle(isOn: Binding { login.status == .enabled } set: { login.setEnabled($0) }) {
            RowLabel(.launchAtLogin, detail: login.status == .requiresApproval ? "Approve in System Settings…" : nil)
        }
        .onAppear(perform: login.refresh)
        .onReceive(windowFocus) { _ in login.refresh() }
    }
}
