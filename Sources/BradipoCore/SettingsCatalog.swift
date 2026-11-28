/// A section of the settings window, in sidebar order.
public enum SettingsSection: CaseIterable, Hashable, Sendable {
    case rhythm, workingHours, breakScreen, sounds, meetings, general

    public var title: String {
        switch self {
        case .rhythm: "Rhythm"
        case .workingHours: "Working Hours"
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
        case .workingHours: [[.workingHoursOnly, .workingHours, .workingDays]]
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
    case workingHoursOnly, workingHours, workingDays
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
        case .workingHoursOnly: "Remind only during working hours"
        case .workingHours: "Hours"
        case .workingDays: "Days"
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

    /// Other words that find the setting in a search: what its control says, and what the menu called it
    /// before the settings moved to a window.
    public var keywords: [String] {
        switch self {
        case .workInterval, .shortBreakLength, .longBreakLength: ["Custom"]
        case .longBreakFrequency: ["Long break after", "Long break frequency"]
        case .workingHoursOnly: ["Schedule"]
        case .workingHours: ["Schedule", "Start", "End", "Time"]
        case .workingDays: ["Schedule", "Weekdays", "Weekends"]
        case .bannerPlacement: ["Reset on All Displays"]
        case .accentColor: ["Restore Default Green"]
        case .startSound: ["Play Sound When Breaks Start"]
        case .endSound: ["Play Sound When Breaks End"]
        case .deferDuringMeetings: ["Microphone", "Camera"]
        case .ignoredApps: ["Microphone"]
        case .version: ["About bradipo"]
        case .updates: ["Check for Updates"]
        case .sourceCode: ["About bradipo", "GitHub", "Commit"]
        default: []
        }
    }

    /// Shown under the title where the title alone doesn't say what the setting does.
    public var detail: String? {
        switch self {
        case .longBreaks: "Turn off to take only short breaks."
        case .workingHoursOnly: "Outside them, no break comes due, and the countdown waits at its full length."
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
