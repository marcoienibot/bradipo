/// One of the macOS alert sounds a break can play.
public struct AlertSound: Sendable {
    /// What `NSSound(named:)` takes and Settings saves: the name of the sound's file in /System/Library/Sounds.
    public let fileName: String
    /// The name System Settings shows for the sound, which macOS 27 gives in place of the file's.
    public let title: String

    /// The alert sounds System Settings offers, sorted by title as the pop-up in Settings lists them.
    public static let all = [
        Self(fileName: "Tink", title: "Boop"),
        Self(fileName: "Blow", title: "Breeze"),
        Self(fileName: "Pop", title: "Bubble"),
        Self(fileName: "Glass", title: "Crystal"),
        Self(fileName: "Funk", title: "Funky"),
        Self(fileName: "Hero", title: "Heroine"),
        Self(fileName: "Frog", title: "Jump"),
        Self(fileName: "Basso", title: "Mezzo"),
        Self(fileName: "Bottle", title: "Pebble"),
        Self(fileName: "Purr", title: "Pluck"),
        Self(fileName: "Morse", title: "Pong"),
        Self(fileName: "Ping", title: "Sonar"),
        Self(fileName: "Sosumi", title: "Sonumi"),
        Self(fileName: "Submarine", title: "Submerge"),
    ]

    /// The file names of the sounds a break plays until others are chosen.
    public static let breakStartDefault = "Purr"
    public static let breakEndDefault = "Glass"

    /// The file name of the sound that plays for a saved one, which Settings shows as chosen: the saved sound if it's
    /// an alert sound, or else the default. A name edited by hand would otherwise play nothing while Settings showed
    /// no sound chosen.
    /// - Parameter saved: Nil or empty until a sound is chosen.
    public static func resolve(_ saved: String?, default fallback: String) -> String {
        if let saved, all.contains(where: { $0.fileName == saved }) { return saved }
        return fallback
    }
}
