import BradipoCore
import Testing

@Test func aChosenSoundPlays() {
    #expect(AlertSound.resolve("Hero", default: "Purr", among: ["Basso", "Hero", "Purr"]) == "Hero")
}

@Test func theDefaultPlaysUntilASoundIsChosen() {
    #expect(AlertSound.resolve(nil, default: "Purr", among: ["Basso", "Hero", "Purr"]) == "Purr")
    // Settings reads a name that was never saved as empty.
    #expect(AlertSound.resolve("", default: "Purr", among: ["Basso", "Hero", "Purr"]) == "Purr")
}

@Test func aSoundMacOSDoesNotHaveFallsBackToTheDefault() {
    // A preference edited by hand, or a sound a later macOS dropped, would play nothing while Settings showed it.
    #expect(AlertSound.resolve("Chime", default: "Purr", among: ["Basso", "Hero", "Purr"]) == "Purr")
}

@Test func withoutTheDefaultTheFirstSoundPlays() {
    // A later macOS could drop the default as well. The first sound is then what both Settings and the break use,
    // rather than a switch that's on and plays nothing.
    #expect(AlertSound.resolve(nil, default: "Purr", among: ["Basso", "Hero"]) == "Basso")
    #expect(AlertSound.resolve("Chime", default: "Purr", among: ["Basso", "Hero"]) == "Basso")
}

@Test func withoutAnySoundsNothingPlays() {
    // Settings then has no sound to show as chosen, so it leaves out the pop-up.
    #expect(AlertSound.resolve("Hero", default: "Purr", among: []) == nil)
}
