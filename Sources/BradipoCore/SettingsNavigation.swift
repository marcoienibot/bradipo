/// Where the settings window is, and where its search takes it.
///
/// Typing only previews: the best match shows at once, and emptying the query goes back to the section chosen
/// before the search. A click, an arrow key or Return chooses a place, so its section stays afterwards.
public struct SettingsNavigation: Sendable {
    /// The place the window shows. While a search finds nothing, it's the last place shown.
    public private(set) var selection = SettingsSearch.Place(section: .rhythm)
    /// The section last chosen, which a search that's given up goes back to.
    private var home = SettingsSection.rhythm
    public var query = "" {
        didSet { selection = results == nil ? .init(section: home) : places.first ?? selection }
    }

    public init() {}

    /// Nil while there's no search.
    private var results: (sections: [SettingsSearch.Hit], settings: [SettingsSearch.Hit])? {
        query.allSatisfy(\.isWhitespace) ? nil : SettingsSearch.results(for: query)
    }

    /// The sections the sidebar lists: all of them, or during a search the ones whose own titles match.
    public var sections: [SettingsSearch.Hit] {
        results?.sections ?? SettingsSection.allCases.map { .init(place: .init(section: $0)) }
    }

    /// The settings a search found, which the sidebar lists under the sections.
    public var settings: [SettingsSearch.Hit] {
        results?.settings ?? []
    }

    /// Every place the sidebar lists, from top to bottom.
    public var places: [SettingsSearch.Place] {
        (sections + settings).map(\.place)
    }

    /// For a click on a row of the sidebar.
    public mutating func choose(_ place: SettingsSearch.Place) {
        selection = place
        home = place.section
    }

    /// For the arrow keys: chooses the place this many rows down the sidebar, or up if negative,
    /// stopping at the first and the last.
    public mutating func move(by offset: Int) {
        let places = places
        guard let index = places.firstIndex(of: selection) else { return }
        choose(places[min(max(index + offset, 0), places.count - 1)])
    }

    /// For Return, and for a click on the row that typing already selected: chooses the selection and says so,
    /// unless a search that found nothing left it unlisted.
    @discardableResult
    public mutating func chooseSelection() -> Bool {
        guard places.contains(selection) else { return false }
        choose(selection)
        return true
    }
}
