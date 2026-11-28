import BradipoCore
import Foundation
import Testing

/// In 2026, Rome's clocks go forward an hour on Sunday 29 March at 2:00, and back on Sunday 25 October at 3:00.
private let rome = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
    return calendar
}()

/// A moment written with its offset from UTC, which tells apart the two 2:30s on the night the clocks go back.
private func moment(_ text: String) -> Date {
    try! Date(text, strategy: .iso8601)
}

/// 30 November 2026 is a Monday.
private let nineToFive = WorkingHours(start: 9 * 60, end: 17 * 60, days: .mondayToFriday)

@Test func hoursIncludeTheirStartButNotTheirEnd() {
    #expect(!nineToFive.contains(moment("2026-11-30T08:59:59+01:00"), in: rome))
    #expect(nineToFive.contains(moment("2026-11-30T09:00:00+01:00"), in: rome))
    #expect(nineToFive.contains(moment("2026-11-30T16:59:59+01:00"), in: rome))
    #expect(!nineToFive.contains(moment("2026-11-30T17:00:00+01:00"), in: rome))
}

@Test func aDayThatIsNotChosenHasNoHours() {
    // Saturday at noon.
    #expect(!nineToFive.contains(moment("2026-12-05T12:00:00+01:00"), in: rome))
}

@Test func theNextChangeIsTheEndDuringTheHoursAndTheStartOutsideThem() {
    #expect(nineToFive.nextChange(after: moment("2026-11-30T07:00:00+01:00"), in: rome)
        == moment("2026-11-30T09:00:00+01:00"))
    // A moment at the start is already in the hours.
    #expect(nineToFive.nextChange(after: moment("2026-11-30T09:00:00+01:00"), in: rome)
        == moment("2026-11-30T17:00:00+01:00"))
    #expect(nineToFive.nextChange(after: moment("2026-11-30T17:00:00+01:00"), in: rome)
        == moment("2026-12-01T09:00:00+01:00"))
}

@Test func theNextStartSkipsTheDaysThatAreNotChosen() {
    // From Friday evening, the hours begin again on Monday.
    #expect(nineToFive.nextChange(after: moment("2026-12-04T17:00:00+01:00"), in: rome)
        == moment("2026-12-07T09:00:00+01:00"))
}

@Test func hoursOnASingleDayBeginAgainAWeekLater() {
    let mondays = WorkingHours(start: 9 * 60, end: 17 * 60, days: .monday)
    #expect(mondays.nextChange(after: moment("2026-11-30T18:00:00+01:00"), in: rome)
        == moment("2026-12-07T09:00:00+01:00"))
}

@Test func hoursThatEndBeforeTheyStartRunPastMidnight() {
    let fridayNights = WorkingHours(start: 22 * 60, end: 6 * 60, days: .friday)
    #expect(fridayNights.contains(moment("2026-12-04T23:00:00+01:00"), in: rome))
    // Early on Saturday is still in Friday's hours, though Saturday isn't chosen.
    #expect(fridayNights.contains(moment("2026-12-05T05:59:00+01:00"), in: rome))
    #expect(!fridayNights.contains(moment("2026-12-05T06:00:00+01:00"), in: rome))
    #expect(fridayNights.nextChange(after: moment("2026-12-04T23:00:00+01:00"), in: rome)
        == moment("2026-12-05T06:00:00+01:00"))
}

@Test func theDayOvernightHoursStartOnDecidesWhetherTheyApply() {
    let fridayNights = WorkingHours(start: 22 * 60, end: 6 * 60, days: .friday)
    // Early on Friday would be in Thursday's hours, and Thursday isn't chosen.
    #expect(!fridayNights.contains(moment("2026-12-04T05:00:00+01:00"), in: rome))
    #expect(fridayNights.nextChange(after: moment("2026-12-04T05:00:00+01:00"), in: rome)
        == moment("2026-12-04T22:00:00+01:00"))
    // Saturday night isn't in them either.
    #expect(!fridayNights.contains(moment("2026-12-05T23:00:00+01:00"), in: rome))
}

@Test func hoursThatEndAtMidnightEndWithTheirDay() {
    // An end of 0:00 is at or before any start, so it's the midnight after the start.
    let evenings = WorkingHours(start: 18 * 60, end: 0, days: .monday)
    #expect(evenings.contains(moment("2026-11-30T23:59:00+01:00"), in: rome))
    #expect(!evenings.contains(moment("2026-12-01T00:00:00+01:00"), in: rome))
}

@Test func equalTimesCoverWholeDays() {
    let weekdays = WorkingHours(start: 0, end: 0, days: .mondayToFriday)
    #expect(weekdays.contains(moment("2026-11-30T00:00:00+01:00"), in: rome))
    #expect(weekdays.contains(moment("2026-12-04T23:59:59+01:00"), in: rome))
    #expect(!weekdays.contains(moment("2026-12-05T00:00:00+01:00"), in: rome))
    // Each day's hours begin as the day before's end, so from Monday nothing changes until Saturday begins.
    #expect(weekdays.nextChange(after: moment("2026-11-30T10:00:00+01:00"), in: rome)
        == moment("2026-12-05T00:00:00+01:00"))
}

@Test func hoursThatNeverEndHaveNoNextChange() {
    // 24 hours from 9:00 on every day.
    let always = WorkingHours(start: 9 * 60, end: 9 * 60, days: .everyDay)
    #expect(always.contains(moment("2026-11-30T08:00:00+01:00"), in: rome))
    #expect(always.nextChange(after: moment("2026-11-30T08:00:00+01:00"), in: rome) == nil)
}

@Test func withoutDaysThereAreNoHours() {
    let never = WorkingHours(start: 9 * 60, end: 17 * 60, days: [])
    #expect(!never.contains(moment("2026-11-30T10:00:00+01:00"), in: rome))
    #expect(never.nextChange(after: moment("2026-11-30T10:00:00+01:00"), in: rome) == nil)
}

@Test func hoursAreAnHourShorterWhenTheClocksGoForward() {
    // The clock shows 4:00 two hours after 1:00, not three, so the end follows the clock rather than the hours
    // that pass.
    let sundayNight = WorkingHours(start: 1 * 60, end: 4 * 60, days: .sunday)
    #expect(sundayNight.nextChange(after: moment("2026-03-29T01:00:00+01:00"), in: rome)
        == moment("2026-03-29T04:00:00+02:00"))
    #expect(sundayNight.contains(moment("2026-03-29T03:30:00+02:00"), in: rome))
}

@Test func hoursThatStartAtASkippedTimeStartWhenTheClocksJumpPastIt() {
    // The clocks go from 1:59 to 3:00, so 2:30 never shows.
    let hours = WorkingHours(start: 2 * 60 + 30, end: 8 * 60, days: .sunday)
    #expect(!hours.contains(moment("2026-03-29T01:59:00+01:00"), in: rome))
    #expect(hours.contains(moment("2026-03-29T03:00:00+02:00"), in: rome))
    #expect(hours.nextChange(after: moment("2026-03-28T22:00:00+01:00"), in: rome)
        == moment("2026-03-29T03:00:00+02:00"))
}

@Test func overnightHoursFollowTheClocksIntoTheNextDay() {
    // From Saturday 22:00 to Sunday 6:00 the clocks go forward, so the end is 6:00 summer time.
    let saturdayNight = WorkingHours(start: 22 * 60, end: 6 * 60, days: .saturday)
    #expect(saturdayNight.nextChange(after: moment("2026-03-28T23:00:00+01:00"), in: rome)
        == moment("2026-03-29T06:00:00+02:00"))
}

@Test func hoursAreAnHourLongerWhenTheClocksGoBack() {
    // The clock shows 6:00 seven hours after midnight, as it shows 2:00 to 2:59 twice.
    let sundayNight = WorkingHours(start: 0, end: 6 * 60, days: .sunday)
    #expect(sundayNight.nextChange(after: moment("2026-10-25T00:00:00+02:00"), in: rome)
        == moment("2026-10-25T06:00:00+01:00"))
}

@Test func hoursThatStartAtARepeatedTimeStartTheFirstTime() {
    // 2:30 shows in summer time, then an hour later in winter time.
    let hours = WorkingHours(start: 2 * 60 + 30, end: 8 * 60, days: .sunday)
    #expect(hours.nextChange(after: moment("2026-10-25T00:00:00+02:00"), in: rome)
        == moment("2026-10-25T02:30:00+02:00"))
    // When the clocks go back, they show a time before the start again. The hours go on regardless.
    #expect(hours.contains(moment("2026-10-25T02:10:00+01:00"), in: rome))
    #expect(hours.nextChange(after: moment("2026-10-25T02:30:00+02:00"), in: rome)
        == moment("2026-10-25T08:00:00+01:00"))
}
