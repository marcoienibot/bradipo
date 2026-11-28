/// The UserDefaults keys that the app and its settings window share. `AppDelegate` registers their defaults at
/// launch, so the fallback that `@AppStorage` asks for is never used.
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
}
