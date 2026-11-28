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

@Test func searchFindsASettingAndItsSection() {
    let results = SettingsSearch.results(for: "glow")
    #expect(results.sections.isEmpty)
    #expect(results.settings.map(\.setting) == [.glowIntensity])
    #expect(results.settings.map(\.section) == [.breakScreen])
}

@Test func searchListsAMatchingSectionApartFromItsSettings() {
    let results = SettingsSearch.results(for: "sound")
    #expect(results.sections.map(\.section) == [.sounds])
    #expect(results.sections.map(\.setting) == [nil])
    #expect(results.settings.map(\.setting) == [.startSound, .endSound])
}
