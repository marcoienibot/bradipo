import BradipoCore
import SwiftUI

/// SwiftUI's `@State` is a macro in the macOS 27 SDK, and its plug-in ships only with Xcode.
/// The property wrapper of the same name still builds with the Command Line Tools.
typealias ViewState = State

/// A sidebar of sections next to the selected section's form, like System Settings.
/// Typing in the sidebar's search field lists the sections and settings that match instead.
struct SettingsView: View {
    let host: SettingsHost
    @ViewState private var query = ""
    @ViewState private var selection = SettingsSearch.Place(section: .rhythm)
    /// The section the person last chose, which a search that's given up goes back to.
    @ViewState private var home = SettingsSection.rhythm
    /// The setting a search result points at, marked in its form for a moment.
    @ViewState private var marked: Setting?
    @ViewState private var unmark: Task<Void, Never>?

    /// Nil while the sidebar shows the sections.
    private var results: (sections: [SettingsSearch.Hit], settings: [SettingsSearch.Hit])? {
        query.allSatisfy(\.isWhitespace) ? nil : SettingsSearch.results(for: query)
    }
    /// During a search, only the sections whose own titles match.
    private var sections: [SettingsSearch.Hit] {
        results?.sections ?? SettingsSection.allCases.map { .init(place: .init(section: $0)) }
    }
    private var sidebarPlaces: [SettingsSearch.Place] {
        (sections + (results?.settings ?? [])).map(\.place)
    }

    var body: some View {
        // The sidebar is the only way around, so it can't be collapsed.
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 6) {
                SearchField(text: $query, move: moveSelection, submit: { choose(selection) })
                    .padding(.horizontal, 10)
                ScrollViewReader { list in
                    // A list's selection is optional, but a section is always showing.
                    List(selection: Binding { selection } set: { if let place = $0 { choose(place) } }) {
                        ForEach(sections, id: \.place, content: SidebarLabel.init)
                        if let settings = results?.settings, !settings.isEmpty {
                            Section("Settings") {
                                ForEach(settings, id: \.place, content: SidebarLabel.init)
                            }
                        }
                    }
                    .overlay {
                        if sidebarPlaces.isEmpty { ContentUnavailableView.search(text: query) }
                    }
                    // The arrow keys move the selection from the search field, which doesn't scroll the list.
                    .onChange(of: selection) { list.scrollTo(selection) }
                }
            }
            .toolbar(removing: .sidebarToggle)
            // The width only takes effect as the column's outermost modifier.
            .navigationSplitViewColumnWidth(215)
        } detail: {
            ScrollViewReader { form in
                Form {
                    ForEach(selection.section.groups, id: \.self) { group in
                        Section {
                            ForEach(group, id: \.self) { setting in
                                SettingRow(setting: setting, host: host)
                                    .background {
                                        // A grouped form ignores a row background, so reach past the row's padding.
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.accentColor.opacity(setting == marked ? 0.2 : 0))
                                            .padding(.horizontal, -8)
                                            .padding(.vertical, -5)
                                    }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                // A long section can have the row scrolled out of sight. A grouped form scrolls to its boxes,
                // which the groups identify, but not to the rows inside them.
                .onChange(of: marked) {
                    if let marked, let box = selection.section.groups.first(where: { $0.contains(marked) }) {
                        form.scrollTo(box, anchor: .top)
                    }
                }
            }
            .navigationTitle(selection.section.title)
        }
        .frame(width: 720, height: 480)
        // Esc ends a search from anywhere in the window. The search field does it for itself.
        .onExitCommand { query = "" }
        .onChange(of: query) {
            // The best match shows as someone types, and without a match the form stays as it is.
            // Emptying the field without having chosen a result gives the search up.
            selection = results == nil ? .init(section: home) : sidebarPlaces.first ?? selection
        }
        .onChange(of: selection) { mark() }
    }

    /// A click, an arrow key or Return chooses a place. Typing only shows the best match.
    private func choose(_ place: SettingsSearch.Place) {
        selection = place
        home = place.section
        mark()
    }

    private func moveSelection(by offset: Int) {
        let places = sidebarPlaces
        guard let index = places.firstIndex(of: selection) else { return }
        choose(places[min(max(index + offset, 0), places.count - 1)])
    }

    private func mark() {
        unmark?.cancel()
        marked = selection.setting
        guard marked != nil else { return }
        unmark = Task {
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled { withAnimation { marked = nil } }
        }
    }
}

/// A section's symbol on a colored tile beside the title of the section or of one of its settings,
/// with the letters a search matched picked out.
private struct SidebarLabel: View {
    let hit: SettingsSearch.Hit

    var body: some View {
        Label {
            // Two settings can differ only in their last words.
            Text(title).lineLimit(2)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        // Only the tile's symbol shows which section a setting is in.
        .accessibilityLabel(place.setting == nil ? place.title : "\(place.title), \(place.section.title)")
    }

    private var place: SettingsSearch.Place { hit.place }

    private var title: AttributedString {
        var title = AttributedString(place.title)
        for match in hit.matches {
            if let range = Range(match, in: title) { title[range].backgroundColor = .accentColor.opacity(0.35) }
        }
        return title
    }

    private var symbol: String {
        switch place.section {
        case .rhythm: "timer"
        case .breakScreen: "sparkles"
        case .sounds: "speaker.wave.2.fill"
        case .meetings: "video.fill"
        case .general: "gearshape.fill"
        }
    }

    private var tint: Color {
        switch place.section {
        case .rhythm: .green
        case .breakScreen: .purple
        case .sounds: .pink
        case .meetings: .teal
        case .general: .gray
        }
    }
}

/// AppKit's search field, whose delegate hears the arrow keys and Return while the field keeps the keyboard,
/// so they can move through the sidebar as someone types.
private struct SearchField: NSViewRepresentable {
    @Binding var text: String
    /// Moves the sidebar's selection down by this many rows, or up if negative.
    let move: (Int) -> Void
    let submit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search"
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(_ parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField { parent.text = field.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveDown(_:)): parent.move(1)
            case #selector(NSResponder.moveUp(_:)): parent.move(-1)
            case #selector(NSResponder.insertNewline(_:)): parent.submit()
            default: return false
            }
            return true
        }
    }
}
