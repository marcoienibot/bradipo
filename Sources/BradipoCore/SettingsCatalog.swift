/// A section of the settings window, in sidebar order.
public enum SettingsSection: CaseIterable, Hashable, Sendable {
    case rhythm, breakScreen, sounds, meetings, general

    public var title: String {
        switch self {
        case .rhythm: "Rhythm"
        case .breakScreen: "Break Screen"
        case .sounds: "Sounds"
        case .meetings: "Meetings"
        case .general: "General"
        }
    }

    /// The section's settings in the order shown. Each inner array is one box of the form.
    public var groups: [[Setting]] {
        switch self {
        case .rhythm: [[.workInterval, .shortBreakLength], [.longBreaks, .longBreakLength, .longBreakFrequency]]
        case .breakScreen: [[.showBanner, .bannerPlacement], [.accentColor, .glowIntensity], [.screenSharing]]
        case .sounds: [[.startSound, .endSound]]
        case .meetings: [[.deferDuringMeetings], [.ignoredApps]]
        case .general: [[.launchAtLogin], [.version, .updates, .sourceCode]]
        }
    }
}

/// A row of the settings window. The window takes each row's words and its place from here.
public enum Setting: CaseIterable, Hashable, Sendable {
    case workInterval, shortBreakLength, longBreaks, longBreakLength, longBreakFrequency
    case showBanner, bannerPlacement, accentColor, glowIntensity, screenSharing
    case startSound, endSound
    case deferDuringMeetings, ignoredApps
    case launchAtLogin, version, updates, sourceCode

    public var title: String {
        switch self {
        case .workInterval: "Work interval"
        case .shortBreakLength: "Short break length"
        case .longBreaks: "Long breaks"
        case .longBreakLength: "Long break length"
        case .longBreakFrequency: "Short breaks before a long break"
        case .showBanner: "Show the break banner"
        case .bannerPlacement: "Banner size and position"
        case .accentColor: "Accent color"
        case .glowIntensity: "Border glow intensity"
        case .screenSharing: "Show breaks in screen sharing"
        case .startSound: "Play a sound when a break starts"
        case .endSound: "Play a sound when a break ends"
        case .deferDuringMeetings: "Defer breaks during meetings"
        case .ignoredApps: "Ignored apps"
        case .launchAtLogin: "Launch at login"
        case .version: "Version"
        case .updates: "Updates"
        case .sourceCode: "Source code"
        }
    }

    /// Shown under the title where the title alone doesn't say what the setting does.
    public var detail: String? {
        switch self {
        case .longBreaks: "Turn off to take only short breaks."
        case .showBanner: "Without it, a break shows only the border glow."
        case .bannerPlacement: "Drag the banner during a break to move or resize it."
        case .accentColor: "Colors the border glow and the banner."
        case .glowIntensity: "Previews on every display while you drag. At 0% the border disappears."
        case .screenSharing: "Also in recordings and screenshots. Some capture apps might show breaks anyway."
        case .startSound: "Not when you start the break yourself."
        case .endSound: "Only after a break that runs its full length."
        case .deferDuringMeetings: "A break that comes due waits while another app uses the microphone or camera."
        case .ignoredApps: "An ignored app can use the microphone without holding breaks. The camera always holds them."
        case .updates: "bradipo never checks on its own."
        default: nil
        }
    }
}
