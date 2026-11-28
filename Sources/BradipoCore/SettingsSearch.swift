import Foundation

/// Finds sections and settings of the settings window by the words in their titles.
public enum SettingsSearch {
    /// A place in the window that a search found: a section, or one setting in its section.
    public struct Hit: Hashable, Sendable {
        public let section: SettingsSection
        /// Nil when the hit is the section itself.
        public let setting: Setting?
        /// The parts of `title` that the query matched.
        public let matches: [Range<String.Index>]
        public var title: String { setting?.title ?? section.title }

        public init(section: SettingsSection, setting: Setting? = nil, matches: [Range<String.Index>] = []) {
            self.section = section
            self.setting = setting
            self.matches = matches
        }
    }

    /// The sections whose own titles match, then the matching settings of every section.
    public static func results(for query: String) -> (sections: [Hit], settings: [Hit]) {
        let sections = search(query, in: SettingsSection.allCases, title: \.title)
            .map { Hit(section: $0.item, matches: $0.matches) }
        let placed = SettingsSection.allCases.flatMap { section in section.groups.joined().map { (section, $0) } }
        let settings = search(query, in: placed, title: \.1.title)
            .map { Hit(section: $0.item.0, setting: $0.item.1, matches: $0.matches) }
        return (sections, settings)
    }

    /// The items whose titles contain every word of the query, ignoring case and accents, each with the ranges
    /// of its title that matched. Items matched at the start of their words come first, as someone looking for
    /// "in" more likely means "interval" than "login". Otherwise the items keep their order.
    public static func search<Item>(_ query: String, in items: [Item], title: (Item) -> String)
        -> [(item: Item, matches: [Range<String.Index>])] {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return [] }
        var atWordStarts: [(Item, [Range<String.Index>])] = []
        var elsewhere: [(Item, [Range<String.Index>])] = []
        for item in items {
            let title = title(item)
            var matches: [Range<String.Index>] = []
            var startsWords = true
            for word in words {
                guard let match = range(of: word, in: title) else { break }
                matches.append(match.range)
                startsWords = startsWords && match.startsWord
            }
            guard matches.count == words.count else { continue }
            if startsWords { atWordStarts.append((item, matches)) } else { elsewhere.append((item, matches)) }
        }
        return (atWordStarts + elsewhere).map { (item: $0.0, matches: $0.1) }
    }

    /// The first place a word of the query starts a word of the title, or else the first place it occurs at all.
    private static func range(of word: Substring, in title: String) -> (range: Range<String.Index>, startsWord: Bool)? {
        var first: Range<String.Index>?
        var rest = title.startIndex..<title.endIndex
        while let found = title.range(of: word, options: [.caseInsensitive, .diacriticInsensitive], range: rest) {
            if found.lowerBound == title.startIndex || !title[title.index(before: found.lowerBound)].isLetter {
                return (found, true)
            }
            first = first ?? found
            rest = title.index(after: found.lowerBound)..<title.endIndex
        }
        return first.map { ($0, false) }
    }
}
