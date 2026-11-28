import BradipoCore
import Testing

private typealias Place = SettingsSearch.Place

@Test func settingsOpenOnTheFirstSection() {
    #expect(SettingsNavigation().selection == Place(section: .rhythm))
}

@Test func typingShowsTheBestMatchAndEmptyingTheQueryGoesBack() {
    var navigation = SettingsNavigation()
    navigation.choose(Place(section: .meetings))
    navigation.query = "glow"
    #expect(navigation.selection == Place(section: .breakScreen, setting: .glowIntensity))
    // Typing only previewed the result, so giving the search up returns to the section chosen before it.
    navigation.query = ""
    #expect(navigation.selection == Place(section: .meetings))
}

@Test func clickingThePreviewedResultChoosesIt() {
    var navigation = SettingsNavigation()
    navigation.choose(Place(section: .breakScreen))
    navigation.query = "work interval"
    // Typing already selected the only result, so the click has no other row to report. It still counts.
    #expect(navigation.selection == Place(section: .rhythm, setting: .workInterval))
    navigation.chooseSelection()
    navigation.query = ""
    #expect(navigation.selection == Place(section: .rhythm))
}

@Test func clickingAnotherResultChoosesIt() {
    var navigation = SettingsNavigation()
    navigation.query = "sound"
    navigation.choose(Place(section: .sounds, setting: .endSound))
    #expect(navigation.selection == Place(section: .sounds, setting: .endSound))
    navigation.query = ""
    #expect(navigation.selection == Place(section: .sounds))
}

@Test func returnChoosesTheSelectedResult() {
    var navigation = SettingsNavigation()
    navigation.query = "glow"
    let chose = navigation.chooseSelection()
    #expect(chose)
    navigation.query = ""
    #expect(navigation.selection == Place(section: .breakScreen))
}

@Test func returnChoosesNothingWhileTheSearchFindsNothing() {
    var navigation = SettingsNavigation()
    navigation.query = "glow"
    navigation.query = "glowxyz"
    // The form keeps showing the glow setting, but the sidebar lists nothing that Return could choose.
    #expect(navigation.places.isEmpty)
    #expect(navigation.selection == Place(section: .breakScreen, setting: .glowIntensity))
    let chose = navigation.chooseSelection()
    #expect(!chose)
    navigation.query = ""
    #expect(navigation.selection == Place(section: .rhythm))
}

@Test func arrowKeysChooseAndStopAtTheFirstAndLastResult() {
    var navigation = SettingsNavigation()
    // The sidebar lists the Sounds section, then the two sound settings.
    navigation.query = "sound"
    #expect(navigation.selection == Place(section: .sounds))
    navigation.move(by: -1)
    #expect(navigation.selection == Place(section: .sounds))
    navigation.move(by: 1)
    #expect(navigation.selection == Place(section: .sounds, setting: .startSound))
    navigation.move(by: 1)
    #expect(navigation.selection == Place(section: .sounds, setting: .endSound))
    navigation.move(by: 1)
    #expect(navigation.selection == Place(section: .sounds, setting: .endSound))
    // The search began on Rhythm, so staying on Sounds shows that the arrow keys chose.
    navigation.query = ""
    #expect(navigation.selection == Place(section: .sounds))
}

@Test func arrowKeysDoNothingWhileTheSearchFindsNothing() {
    var navigation = SettingsNavigation()
    navigation.query = "glowxyz"
    navigation.move(by: 1)
    navigation.query = ""
    #expect(navigation.selection == Place(section: .rhythm))
}

@Test func withoutASearchTheSidebarListsEverySection() {
    let navigation = SettingsNavigation()
    #expect(navigation.sections.map(\.place.section) == [.rhythm, .breakScreen, .sounds, .meetings, .general])
    #expect(navigation.settings.isEmpty)
}
