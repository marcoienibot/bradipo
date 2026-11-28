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
    @ViewState private var selection = SettingsSearch.Hit(section: .rhythm)
    /// The setting a search result points at, marked in its form for a moment.
    @ViewState private var marked: Setting?
    @ViewState private var unmark: Task<Void, Never>?

    /// Nil while the sidebar shows the sections.
    private var results: (sections: [SettingsSearch.Hit], settings: [SettingsSearch.Hit])? {
        query.allSatisfy(\.isWhitespace) ? nil : SettingsSearch.results(for: query)
    }
    private var sidebarItems: [SettingsSearch.Hit] {
        results.map { $0.sections + $0.settings } ?? SettingsSection.allCases.map { .init(section: $0) }
    }

    var body: some View {
        // The sidebar is the only way around, so it can't be collapsed.
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 6) {
                SearchField(text: $query, move: moveSelection, submit: mark)
                    .padding(.horizontal, 10)
                ScrollViewReader { list in
                    // A list's selection is optional, but a section is always showing.
                    List(selection: Binding { selection } set: { selection = $0 ?? selection }) {
                        // During a search, only the sections whose own titles match.
                        ForEach(results?.sections ?? sidebarItems, id: \.self, content: SidebarLabel.init)
                        if let settings = results?.settings, !settings.isEmpty {
                            Section("Settings") {
                                ForEach(settings, id: \.self, content: SidebarLabel.init)
                            }
                        }
                    }
                    .overlay {
                        if sidebarItems.isEmpty { ContentUnavailableView.search(text: query) }
                    }
                    // The arrow keys move the selection from the search field, which doesn't scroll the list.
                    .onChange(of: selection) { list.scrollTo(selection) }
                }
            }
            .toolbar(removing: .sidebarToggle)
            // The width only takes effect as the column's outermost modifier.
            .navigationSplitViewColumnWidth(215)
        } detail: {
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
            .navigationTitle(selection.section.title)
        }
        .frame(width: 720, height: 480)
        .onChange(of: query) {
            // The best match shows at once. Without a match, and after the search, the section stays.
            selection = (results == nil ? nil : sidebarItems.first) ?? .init(section: selection.section)
        }
        .onChange(of: selection) { mark() }
    }

    private func moveSelection(by offset: Int) {
        let items = sidebarItems
        guard let index = items.firstIndex(of: selection) else { return }
        selection = items[min(max(index + offset, 0), items.count - 1)]
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
    }

    private var title: AttributedString {
        var title = AttributedString(hit.title)
        for match in hit.matches {
            if let range = Range(match, in: title) { title[range].backgroundColor = .accentColor.opacity(0.35) }
        }
        return title
    }

    private var symbol: String {
        switch hit.section {
        case .rhythm: "timer"
        case .breakScreen: "sparkles"
        case .sounds: "speaker.wave.2.fill"
        case .meetings: "video.fill"
        case .general: "gearshape.fill"
        }
    }

    private var tint: Color {
        switch hit.section {
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
        // Typing right after the window opens searches, as in System Settings. The field has no window yet.
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
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
