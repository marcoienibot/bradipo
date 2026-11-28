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
    // Stopping at the last result still chooses it, which is what makes the window mark its row again.
    let choseTheLastResultAgain = navigation.move(by: 1)
    #expect(choseTheLastResultAgain)
    #expect(navigation.selection == Place(section: .sounds, setting: .endSound))
    // The search began on Rhythm, so staying on Sounds shows that the arrow keys chose.
    navigation.query = ""
    #expect(navigation.selection == Place(section: .sounds))
}

@Test func settingTheSameQueryAgainKeepsAnArrowKeyChoice() {
    var navigation = SettingsNavigation()
    navigation.query = "sound"
    navigation.move(by: 1)
    // The search field reports its text once more a moment after typing stops.
    navigation.query = "sound"
    #expect(navigation.selection == Place(section: .sounds, setting: .startSound))
}

@Test func arrowKeysChooseNothingWhileTheSearchFindsNothing() {
    var navigation = SettingsNavigation()
    navigation.query = "glow"
    navigation.query = "glowxyz"
    // The form keeps showing the glow setting, which an arrow key mustn't turn into a choice.
    let chose = navigation.move(by: 1)
    #expect(!chose)
    navigation.query = ""
    #expect(navigation.selection == Place(section: .rhythm))
}

@Test func aQueryOfSpacesGoesBackLikeAnEmptyOne() {
    var navigation = SettingsNavigation()
    navigation.choose(Place(section: .meetings))
    navigation.query = "glow"
    navigation.query = "   "
    #expect(navigation.selection == Place(section: .meetings))
    // The sidebar lists the sections again, not the results of a search for spaces.
    #expect(navigation.settings.isEmpty)
    #expect(navigation.sections.count == 6)
}

@Test func typingMoreAfterAChoiceShowsTheNewBestMatchButGoesBackToTheChoice() {
    var navigation = SettingsNavigation()
    navigation.query = "sound"
    navigation.move(by: 1)
    // Typing previews again. It doesn't replace the section that the arrow key chose.
    navigation.query = "glow"
    #expect(navigation.selection == Place(section: .breakScreen, setting: .glowIntensity))
    navigation.query = ""
    #expect(navigation.selection == Place(section: .sounds))
}

@Test func withoutASearchTheSidebarListsEverySection() {
    let navigation = SettingsNavigation()
    #expect(navigation.sections.map(\.place.section) == [.rhythm, .workingHours, .breakScreen, .sounds, .meetings, .general])
    #expect(navigation.settings.isEmpty)
}
