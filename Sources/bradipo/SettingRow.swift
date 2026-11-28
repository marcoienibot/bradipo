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
            SoundRow(setting: setting, sound: .start)
        case .endSound:
            SoundRow(setting: setting, sound: .end)
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

/// A break sound's switch, with a pop-up beside it that chooses the sound and plays it.
/// A break reads both when it plays the sound, so there's nothing to apply.
private struct SoundRow: View {
    let setting: Setting
    let sound: BreakSound
    @AppStorage private var isOn: Bool
    @AppStorage private var saved: String

    init(setting: Setting, sound: BreakSound) {
        self.setting = setting
        self.sound = sound
        _isOn = AppStorage(wrappedValue: false, sound.isOnKey)
        _saved = AppStorage(wrappedValue: "", sound.fileNameKey)
    }

    var body: some View {
        LabeledContent {
            // Two rows have this pop-up, and VoiceOver can read its label without its row's.
            Picker("\(setting.title), sound", selection: Binding { sound.fileName(saved: saved) } set: { fileName in
                saved = fileName
                BreakSound.play(fileName)
            }) {
                ForEach(AlertSound.all, id: \.fileName) { Text($0.title).tag($0.fileName) }
            }
            .labelsHidden()
            .fixedSize()
            // Like the long-break rows, the choice is greyed out while it doesn't matter.
            .disabled(!isOn)
            // A form only draws a row's own toggle as a switch, and this one would otherwise be a checkbox.
            Toggle(setting.title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        } label: {
            RowLabel(setting)
        }
    }
}

/// A pop-up of preset lengths, with fields beside it to type any other length.
private struct DurationPicker: View {
    /// Stands for the Custom item, since no length is negative.
    private static let custom = -1
    let setting: Setting
    let presets: [Int]
    let apply: () -> Void
    @AppStorage private var saved: Int
    /// Shows the fields from choosing Custom until Return or leaving them saves the length in them. Choosing a preset
    /// or pressing Esc puts them away without saving it.
    @ViewState private var isEditing = false
    /// What the fields show, kept as the text typed, so the length is read from both fields at once when it's saved.
    @ViewState private var draft = DurationDraft(0)
    @FocusState private var focus: Field?
    private var seconds: Int { ScheduleLimits.seconds(saved) }
    /// The presets, with a saved length that isn't one among them, so the pop-up shows what's saved.
    private var lengths: [Int] { presets.contains(seconds) ? presets : (presets + [seconds]).sorted() }

    private enum Field { case minutes, seconds }

    init(setting: Setting, key: String, presets: [Int], apply: @escaping () -> Void) {
        self.setting = setting
        self.presets = presets
        self.apply = apply
        _saved = AppStorage(wrappedValue: 0, key)
    }

    var body: some View {
        LabeledContent {
            HStack {
                if isEditing {
                    HStack(spacing: 4) {
                        // Three rows have these fields, and VoiceOver can read a field's label without its row's.
                        field("\(setting.title), minutes", text: $draft.minutes, focus: .minutes)
                        unit("min")
                        field("\(setting.title), seconds", text: $draft.seconds, focus: .seconds)
                        unit("sec")
                    }
                    // onAppear runs before the fields are in the window. Asking for the keyboard then can leave it
                    // nowhere, such as after closing the window mid-edit and opening it again, so it's asked for
                    // once they're in the window.
                    .onAppear { DispatchQueue.main.async { focus = .minutes } }
                    // Esc puts the fields away without saving them, instead of ending a search in the sidebar.
                    .onExitCommand { isEditing = false }
                }
                Picker(setting.title, selection: Binding { isEditing ? Self.custom : seconds } set: { choose($0) }) {
                    ForEach(lengths, id: \.self) { Text(DurationDraft.title($0)).tag($0) }
                    Divider()
                    Text("Custom").tag(Self.custom)
                }
                .labelsHidden()
                .fixedSize()
            }
            // A row's title and the space around the rows don't take the keyboard, so a click there would
            // leave the fields editing. A click on the units, between the fields or on this pop-up keeps editing.
            .background {
                if isEditing { ClickOutside(perform: commit).accessibilityHidden(true) }
            }
        } label: {
            RowLabel(setting)
        }
        // Moving between the two fields keeps editing the same length, so only leaving both saves it.
        .onChange(of: focus) {
            if focus == nil { commit() }
        }
        // The click watcher saves before a click on another section swaps the form. This saves an edit that's
        // still open if the row goes away some other way.
        .onDisappear(perform: commit)
    }

    /// A grouped form draws a text field without a border, which wouldn't look like it takes typing.
    private func field(_ title: String, text: Binding<String>, focus field: Field) -> some View {
        TextField(title, text: text, prompt: Text("0"))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .labelsHidden()
            .frame(width: 40)
            .focused($focus, equals: field)
            .onSubmit(commit)
    }

    private func unit(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            // A click on a unit takes the keyboard from the fields without putting it anywhere, which would
            // save the length as if the click were outside them.
            .allowsHitTesting(false)
    }

    private func choose(_ value: Int) {
        if value == Self.custom {
            // Choosing Custom again while typing keeps what's typed.
            if !isEditing {
                draft = DurationDraft(seconds)
                isEditing = true
            }
        } else {
            // The fields keep the keyboard while the pop-up is open. Putting them away first means they don't
            // save their edit as they lose it, so only the preset is saved.
            isEditing = false
            save(value)
        }
    }

    /// Saves what the fields ask for and puts them away. Something that isn't a length keeps the saved one.
    private func commit() {
        guard isEditing else { return }
        isEditing = false
        save(draft.duration ?? seconds)
    }

    private func save(_ value: Int) {
        // Leaving the fields without changing the length, or choosing the preset that's saved,
        // shouldn't touch the timer.
        guard value != seconds else { return }
        saved = value
        apply()
    }
}

/// Calls its action on a click in its window outside its frame. It watches clicks before they're delivered,
/// so it hears them even where nothing takes the click.
private struct ClickOutside: NSViewRepresentable {
    let perform: () -> Void

    func makeNSView(context: Context) -> Watcher {
        Watcher()
    }

    func updateNSView(_ view: Watcher, context: Context) {
        view.perform = perform
    }

    final class Watcher: NSView {
        var perform: () -> Void = {}
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                if let self, event.window === self.window,
                   !self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                    self.perform()
                }
                return event
            }
        }

        /// Clicks go on to the pop-up and fields in front of it.
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
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
