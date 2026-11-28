import BradipoCore

/// The UserDefaults keys that the app and its settings window share. `AppDelegate` registers a default for each
/// setting that starts out on or with a number. The others start out off or empty, like the `false` that
/// `@AppStorage` falls back to.
enum DefaultsKey {
    static let workSeconds = "workSeconds"
    static let breakSeconds = "breakSeconds"
    static let longBreaksEnabled = "longBreaksEnabled"
    static let longBreakSeconds = "longBreakSeconds"
    static let shortBreaksBeforeLongBreak = "shortBreaksBeforeLongBreak"
    static let showBreakBanner = "showBreakBanner"
    static let showBreaksInScreenSharing = "showBreaksInScreenSharing"
    static let breakStartSound = "breakStartSoundEnabled"
    static let breakEndSound = "breakEndSoundEnabled"
    static let deferBreaksDuringMeetings = "pauseDuringMeetings"
    static let ignoredMeetingApps = "ignoredMeetingApps"
    static let workingHoursOnly = "workingHoursOnly"
    /// Minutes after midnight.
    static let workingHoursStart = "workingHoursStart"
    /// Minutes after midnight.
    static let workingHoursEnd = "workingHoursEnd"
    /// The raw value of `DaysOfWeek`.
    static let workingDays = "workingDays"
}

/// What the timer makes of a saved number, which a preference edited by hand can put out of range.
/// Settings shows the same value the timer runs with.
enum ScheduleLimits {
    /// A work interval or a break length in seconds, from 0:01 to 99:59.
    static func seconds(_ saved: Int) -> Int {
        min(5999, max(1, saved))
    }

    static func shortBreaks(_ saved: Int) -> Int {
        max(1, saved)
    }

    /// A time of day in minutes after midnight, from 0:00 to 23:59.
    static func timeOfDay(_ saved: Int) -> Int {
        min(24 * 60 - 1, max(0, saved))
    }

    /// Without a day, reminders would never come back, so that brings back the default days.
    static func workingDays(_ saved: Int) -> DaysOfWeek {
        let days = DaysOfWeek(rawValue: saved).intersection(.everyDay)
        return days.isEmpty ? .mondayToFriday : days
    }
}
