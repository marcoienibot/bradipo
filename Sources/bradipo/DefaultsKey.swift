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
    /// A sound's file name, rather than the name Settings shows. Empty until a sound is chosen, which leaves
    /// `BreakSound` playing its default.
    static let breakStartSoundName = "breakStartSoundName"
    static let breakEndSoundName = "breakEndSoundName"
    static let deferBreaksDuringMeetings = "pauseDuringMeetings"
    static let ignoredMeetingApps = "ignoredMeetingApps"
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
}
