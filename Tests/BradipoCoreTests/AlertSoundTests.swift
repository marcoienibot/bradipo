import BradipoCore
import Foundation
import Testing

@Test func aChosenSoundPlays() {
    #expect(AlertSound.resolve("Hero", default: "Purr") == "Hero")
}

@Test func theDefaultPlaysUntilASoundIsChosen() {
    #expect(AlertSound.resolve(nil, default: "Purr") == "Purr")
    // Settings reads a name that was never saved as empty.
    #expect(AlertSound.resolve("", default: "Purr") == "Purr")
}

@Test func aNameThatIsNotAnAlertSoundFallsBackToTheDefault() {
    // A preference edited by hand would otherwise play nothing while Settings showed no sound chosen.
    #expect(AlertSound.resolve("Chime", default: "Purr") == "Purr")
    // What's saved is the file name, which NSSound looks up, so the name Settings shows for Hero isn't one.
    #expect(AlertSound.resolve("Heroine", default: "Purr") == "Purr")
}

@Test func theDefaultsArePluckAndCrystal() {
    // A default plays without being looked up, so a misspelled one, such as Pur, would play nothing and leave
    // Settings with no sound chosen.
    #expect(AlertSound.all.first { $0.fileName == AlertSound.breakStartDefault }?.title == "Pluck")
    #expect(AlertSound.all.first { $0.fileName == AlertSound.breakEndDefault }?.title == "Crystal")
}

@Test func everyAlertSoundIsASoundInTheSystemFolder() throws {
    // The table is copied by hand from the system, and NSSound looks a sound up by its file name, so a misspelled
    // one, such as Sosume, would play nothing while Settings showed it as chosen. NSSound also matches the name's
    // case, which the startup disk ignores, so the test reads the folder's names rather than asking if a file exists.
    let files = Set(try FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds"))
    for sound in AlertSound.all {
        #expect(files.contains("\(sound.fileName).aiff"), "No system sound is named \(sound.fileName)")
    }
}
