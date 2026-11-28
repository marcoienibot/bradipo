import Foundation

/// Finds sections and settings of the settings window by the words in their titles.
public enum SettingsSearch {
    /// A place in the window: a section, or one setting in its section.
    public struct Place: Hashable, Sendable {
        public let section: SettingsSection
        /// Nil for the section itself.
        public let setting: Setting?
        public var title: String { setting?.title ?? section.title }

        public init(section: SettingsSection, setting: Setting? = nil) {
            self.section = section
            self.setting = setting
        }
    }

    /// A place that a search found.
    public struct Hit: Sendable {
        public let place: Place
        /// The parts of the place's title that the query matched.
        public let matches: [Range<String.Index>]

        public init(place: Place, matches: [Range<String.Index>] = []) {
            self.place = place
            self.matches = matches
        }
    }

    /// The sections and then the settings that match a query, best match first.
    ///
    /// The window opens the first result as someone types. So a section is only listed when the query starts
    /// the words of its title: "in" finds Work interval rather than Meetings.
    public static func results(for query: String) -> (sections: [Hit], settings: [Hit]) {
        let sections = search(query, in: SettingsSection.allCases.map { Place(section: $0) }, title: \.title)
            .filter(\.startsWords)
        let settings = search(query, in: SettingsSection.allCases.flatMap { section in
            section.groups.joined().map { Place(section: section, setting: $0) }
        }, title: \.title) { $0.setting?.keywords ?? [] }
        return (sections.map { Hit(place: $0.item, matches: $0.matches) },
                settings.map { Hit(place: $0.item, matches: $0.matches) })
    }

    /// The items that every word of the query finds, in their title or else in one of their keywords,
    /// ignoring case, accents and character width. Each comes with the ranges of its title that matched.
    ///
    /// Items whose title has a word starting with each word of the query come first, as someone looking for
    /// "in" more likely means "interval" than "login". Otherwise the items keep their order.
    public static func search<Item>(_ query: String, in items: [Item], title: (Item) -> String,
                                    keywords: (Item) -> [String] = { _ in [] })
        -> [(item: Item, matches: [Range<String.Index>], startsWords: Bool)] {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return [] }
        var found: [(item: Item, matches: [Range<String.Index>], startsWords: Bool)] = []
        for item in items {
            let title = title(item)
            var matches: [Range<String.Index>] = []
            var startsWords = true
            let everyWordFound = words.allSatisfy { word in
                if let match = range(of: word, in: title) {
                    matches.append(match.range)
                    startsWords = startsWords && match.startsWord
                    return true
                }
                startsWords = false
                return keywords(item).contains { range(of: word, in: $0) != nil }
            }
            if everyWordFound { found.append((item, matches, startsWords)) }
        }
        return found.filter(\.startsWords) + found.filter { !$0.startsWords }
    }

    /// The first place a word of the query starts a word of the text, or else the first place it occurs at all.
    private static func range(of word: Substring, in text: String) -> (range: Range<String.Index>, startsWord: Bool)? {
        var first: Range<String.Index>?
        var rest = text.startIndex..<text.endIndex
        while let found = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                                     range: rest) {
            if found.lowerBound == text.startIndex || !text[text.index(before: found.lowerBound)].isLetter {
                return (found, true)
            }
            first = first ?? found
            rest = text.index(after: found.lowerBound)..<text.endIndex
        }
        return first.map { ($0, false) }
    }
}
