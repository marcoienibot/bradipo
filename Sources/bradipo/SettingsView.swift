import BradipoCore
import SwiftUI

/// SwiftUI's `@State` is a macro in the macOS 27 SDK, and its plug-in ships only with Xcode.
/// The property wrapper of the same name still builds with the Command Line Tools.
typealias ViewState = State

/// A sidebar of sections next to the selected section's form, like System Settings.
struct SettingsView: View {
    let host: SettingsHost
    @ViewState private var section = SettingsSection.rhythm

    var body: some View {
        // The sidebar is the only way around, so it can't be collapsed.
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // A list's selection is optional, but a section is always showing.
            List(SettingsSection.allCases, id: \.self, selection: Binding { section } set: { section = $0 ?? section }) {
                SectionLabel(section: $0)
            }
            .toolbar(removing: .sidebarToggle)
            // The width only takes effect as the column's outermost modifier.
            .navigationSplitViewColumnWidth(215)
        } detail: {
            Form {
                ForEach(section.groups, id: \.self) { group in
                    Section {
                        ForEach(group, id: \.self) { SettingRow(setting: $0, host: host) }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(section.title)
        }
        .frame(width: 720, height: 480)
    }
}

/// A section's name beside its symbol on a colored tile.
private struct SectionLabel: View {
    let section: SettingsSection

    var body: some View {
        Label {
            Text(section.title)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }

    private var symbol: String {
        switch section {
        case .rhythm: "timer"
        case .breakScreen: "sparkles"
        case .sounds: "speaker.wave.2.fill"
        case .meetings: "video.fill"
        case .general: "gearshape.fill"
        }
    }

    private var tint: Color {
        switch section {
        case .rhythm: .green
        case .breakScreen: .purple
        case .sounds: .pink
        case .meetings: .teal
        case .general: .gray
        }
    }
}
