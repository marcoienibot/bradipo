import BradipoCore
import Foundation

/// A sound that marks a break starting or finishing, which Settings turns on and chooses.
struct BreakSound {
    let isOnKey: String
    let nameKey: String
    let defaultName: String

    static let start = Self(isOnKey: DefaultsKey.breakStartSound, nameKey: DefaultsKey.breakStartSoundName,
                            defaultName: "Purr")
    static let end = Self(isOnKey: DefaultsKey.breakEndSound, nameKey: DefaultsKey.breakEndSoundName,
                          defaultName: "Glass")

    /// The macOS alert sounds, by the names `NSSound(named:)` takes. They're read from the folder rather than listed
    /// here, so Settings doesn't offer a sound that a later macOS dropped.
    static let choices = ((try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? [])
        .map { ($0 as NSString).deletingPathExtension }
        .sorted()

    /// The sound that plays for a saved name. Settings shows the same one as chosen.
    func name(saved: String?) -> String? {
        AlertSound.resolve(saved, default: defaultName, among: Self.choices)
    }
}
