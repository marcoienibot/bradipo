import BradipoCore
import Testing

/// The titles that match a query, in the order the search returns them.
private func titles(matching query: String, in titles: [String]) -> [String] {
    SettingsSearch.search(query, in: titles) { $0 }.map(\.item)
}

/// The text of each range the search would highlight in a title.
private func highlights(of query: String, in title: String) -> [String]? {
    SettingsSearch.search(query, in: [title]) { $0 }.first?.matches.map { String(title[$0]) }
}

@Test func searchMatchesPartOfATitle() {
    #expect(titles(matching: "key", in: ["Keyboard", "Hyper Key", "Launcher"]) == ["Keyboard", "Hyper Key"])
}

@Test func searchIgnoresCaseAndAccents() {
    #expect(titles(matching: "CAFE", in: ["Café hours"]) == ["Café hours"])
    // The highlight covers the title's own letters, not the query's.
    #expect(highlights(of: "CAFE", in: "Café hours") == ["Café"])
}

@Test func everyWordOfTheQueryHasToMatch() {
    #expect(titles(matching: "long length", in: ["Long breaks", "Long break length"]) == ["Long break length"])
    // The words can come in any order.
    #expect(titles(matching: "length long", in: ["Long breaks", "Long break length"]) == ["Long break length"])
    #expect(highlights(of: "length long", in: "Long break length") == ["length", "Long"])
}

@Test func emptyQueryFindsNothing() {
    // The window shows its sections instead of results then.
    #expect(titles(matching: "", in: ["Keyboard"]) == [])
    #expect(titles(matching: "   ", in: ["Keyboard"]) == [])
}

@Test func matchesAtTheStartOfAWordComeFirst() {
    // "login" only contains "in", while "interval" and "in" start with it.
    #expect(titles(matching: "in", in: ["Launch at login", "Work interval", "Show breaks in screen sharing"])
        == ["Work interval", "Show breaks in screen sharing", "Launch at login"])
}

@Test func highlightPrefersTheStartOfAWord() {
    // "Joining" contains "in" twice before the word "In", whose capital tells the matches apart.
    #expect(highlights(of: "in", in: "Joining In") == ["In"])
}

@Test func aMatchInsideAWordStillCounts() {
    #expect(highlights(of: "ogin", in: "Launch at login") == ["ogin"])
}

@Test func keywordsFindAnItemWithoutHighlightingItsTitle() {
    // The menu called this row "About bradipo" before it moved to the window.
    let found = SettingsSearch.search("about", in: ["Version"], title: { $0 }, keywords: { _ in ["About bradipo"] })
    #expect(found.map(\.item) == ["Version"])
    #expect(found.map(\.matches) == [[]])
}

@Test func wordsFoundInTheTitleAreHighlightedBesideKeywordMatches() {
    // "check" is only in the keyword, "updates" is in both.
    let found = SettingsSearch.search("check updates", in: ["Updates"], title: { $0 }, keywords: { _ in ["Check for Updates"] })
    #expect(found.map { $0.matches.map { String("Updates"[$0]) } } == [["Updates"]])
}

@Test func keywordMatchesComeAfterTitlesThatStartWithTheQuery() {
    // The first result opens as someone types, so a title that says "reset" beats a button that does.
    let keywords = ["Banner size": ["Reset on All Displays"]]
    #expect(SettingsSearch.search("reset", in: ["Banner size", "Reset timer"], title: { $0 }, keywords: { keywords[$0] ?? [] })
        .map(\.item) == ["Reset timer", "Banner size"])
}

@Test func searchIgnoresCharacterWidth() {
    // Japanese input methods can type Latin letters at full width.
    #expect(titles(matching: "ＧＬＯＷ", in: ["Border glow intensity"]) == ["Border glow intensity"])
}

@Test func searchFindsASettingAndItsSection() {
    let results = SettingsSearch.results(for: "glow")
    #expect(results.sections.isEmpty)
    #expect(results.settings.map(\.place.setting) == [.glowIntensity])
    #expect(results.settings.map(\.place.section) == [.breakScreen])
}

@Test func searchListsAMatchingSectionApartFromItsSettings() {
    let results = SettingsSearch.results(for: "sound")
    #expect(results.sections.map(\.place) == [SettingsSearch.Place(section: .sounds)])
    #expect(results.settings.map(\.place.setting) == [.startSound, .endSound])
}

@Test func aSectionIsOnlyListedWhenTheQueryStartsItsWords() {
    // "Meetings" contains "in", but the window opens the first result, and "in" should open Work interval.
    let results = SettingsSearch.results(for: "in")
    #expect(results.sections.isEmpty)
    #expect(results.settings.first?.place.setting == .workInterval)
    // "m" starts "Meetings" and is only inside "Rhythm".
    #expect(SettingsSearch.results(for: "m").sections.map(\.place.section) == [.meetings])
}

@Test func searchFindsSettingsByWhatTheMenuCalledThem() {
    #expect(SettingsSearch.results(for: "check for updates").settings.map(\.place.setting) == [.updates])
    #expect(SettingsSearch.results(for: "about").settings.map(\.place.setting) == [.version, .sourceCode])
}

@Test func searchFindsTheMeetingSettingsByTheirDevices() {
    #expect(SettingsSearch.results(for: "microphone").settings.map(\.place.setting) == [.deferDuringMeetings, .ignoredApps])
    #expect(SettingsSearch.results(for: "camera").settings.map(\.place.setting) == [.deferDuringMeetings])
}

@Test func searchFindsTheWorkingHoursAsASchedule() {
    #expect(SettingsSearch.results(for: "schedule").settings.map(\.place.setting)
        == [.workingHoursOnly, .workingHours, .workingDays])
    #expect(SettingsSearch.results(for: "weekends").settings.map(\.place.setting) == [.workingDays])
}

@Test func searchForHoursOpensTheWorkingHoursSection() {
    // "Hours" starts a word of the section's title, so the section is listed first and opens as someone types.
    let results = SettingsSearch.results(for: "hours")
    #expect(results.sections.map(\.place.section) == [.workingHours])
    #expect(results.settings.map(\.place.setting) == [.workingHoursOnly, .workingHours])
}
