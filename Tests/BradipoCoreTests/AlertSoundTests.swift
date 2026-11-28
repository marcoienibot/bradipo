import BradipoCore
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
