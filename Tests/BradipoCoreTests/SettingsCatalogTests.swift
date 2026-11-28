import BradipoCore
import Testing

@Test func everySettingHasOnePlaceInTheWindow() {
    // A setting left out of every section would show nowhere, and one listed twice would show twice.
    let placed = SettingsSection.allCases.flatMap { $0.groups.joined() }
    #expect(placed.count == Setting.allCases.count)
    #expect(Set(placed) == Set(Setting.allCases))
}

@Test func workingHoursFollowRhythm() {
    // Both decide when breaks come due.
    #expect(Array(SettingsSection.allCases.prefix(2)) == [.rhythm, .workingHours])
    // The switch comes first, above the rows it greys out.
    #expect(SettingsSection.workingHours.groups.first?.first == .workingHoursOnly)
}
