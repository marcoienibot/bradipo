import AppKit
import BradipoCore

/// A sound that marks a break starting or finishing, which Settings turns on and chooses.
struct BreakSound {
    let isOnKey: String
    let fileNameKey: String
    let defaultFileName: String

    static let start = Self(isOnKey: DefaultsKey.breakStartSound, fileNameKey: DefaultsKey.breakStartSoundName,
                            defaultFileName: AlertSound.breakStartDefault)
    static let end = Self(isOnKey: DefaultsKey.breakEndSound, fileNameKey: DefaultsKey.breakEndSoundName,
                          defaultFileName: AlertSound.breakEndDefault)

    @MainActor private static var lastPlayed: NSSound?

    /// The file name of the sound that plays for a saved one. Settings shows the same one as chosen.
    func fileName(saved: String?) -> String {
        AlertSound.resolve(saved, default: defaultFileName)
    }

    /// Plays a sound from the start, stopping the one played last. `NSSound(named:)` hands back one shared sound per
    /// name, which ignores `play()` while it's still playing, and stopping it first makes it start over. Otherwise a
    /// break shorter than its sound would skip the end sound when it's the same as the start one, and a sound
    /// previewed in Settings could swallow a break's. Stopping the last one also keeps quick previews from playing
    /// over each other, as System Settings does.
    @MainActor static func play(_ fileName: String) {
        lastPlayed?.stop()
        lastPlayed = NSSound(named: fileName)
        lastPlayed?.play()
    }
}
