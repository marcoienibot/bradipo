import BradipoCore
import Testing

@Test func everySettingHasOnePlaceInTheWindow() {
    // A setting left out of every section would show nowhere, and one listed twice would show twice.
    let placed = SettingsSection.allCases.flatMap { $0.groups.joined() }
    #expect(placed.count == Setting.allCases.count)
    #expect(Set(placed) == Set(Setting.allCases))
}
