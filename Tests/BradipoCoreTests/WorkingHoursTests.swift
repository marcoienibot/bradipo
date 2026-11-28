import BradipoCore
import Foundation
import Testing

private func calendar(in timeZone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZone)!
    return calendar
}

/// In 2026, Rome's clocks go forward an hour on Sunday 29 March at 2:00, and back on Sunday 25 October at 3:00.
private let rome = calendar(in: "Europe/Rome")

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

@Test func theNextBoundaryIsTheEndDuringTheHoursAndTheStartOutsideThem() {
    #expect(nineToFive.nextBoundary(after: moment("2026-11-30T07:00:00+01:00"), in: rome)
        == moment("2026-11-30T09:00:00+01:00"))
    // A moment at the start is already in the hours.
    #expect(nineToFive.nextBoundary(after: moment("2026-11-30T09:00:00+01:00"), in: rome)
        == moment("2026-11-30T17:00:00+01:00"))
    #expect(nineToFive.nextBoundary(after: moment("2026-11-30T17:00:00+01:00"), in: rome)
        == moment("2026-12-01T09:00:00+01:00"))
}

@Test func theNextStartSkipsTheDaysThatAreNotChosen() {
    // From Friday evening, the hours begin again on Monday.
    #expect(nineToFive.nextBoundary(after: moment("2026-12-04T17:00:00+01:00"), in: rome)
        == moment("2026-12-07T09:00:00+01:00"))
}

@Test func hoursOnASingleDayBeginAgainAWeekLater() {
    let mondays = WorkingHours(start: 9 * 60, end: 17 * 60, days: .monday)
    #expect(mondays.nextBoundary(after: moment("2026-11-30T18:00:00+01:00"), in: rome)
        == moment("2026-12-07T09:00:00+01:00"))
}

@Test func hoursThatEndBeforeTheyStartRunPastMidnight() {
    let fridayNights = WorkingHours(start: 22 * 60, end: 6 * 60, days: .friday)
    #expect(fridayNights.contains(moment("2026-12-04T23:00:00+01:00"), in: rome))
    // Early on Saturday is still in Friday's hours, though Saturday isn't chosen.
    #expect(fridayNights.contains(moment("2026-12-05T05:59:00+01:00"), in: rome))
    #expect(!fridayNights.contains(moment("2026-12-05T06:00:00+01:00"), in: rome))
    #expect(fridayNights.nextBoundary(after: moment("2026-12-04T23:00:00+01:00"), in: rome)
        == moment("2026-12-05T06:00:00+01:00"))
}

@Test func theDayOvernightHoursStartOnDecidesWhetherTheyApply() {
    let fridayNights = WorkingHours(start: 22 * 60, end: 6 * 60, days: .friday)
    // Early on Friday would be in Thursday's hours, and Thursday isn't chosen.
    #expect(!fridayNights.contains(moment("2026-12-04T05:00:00+01:00"), in: rome))
    #expect(fridayNights.nextBoundary(after: moment("2026-12-04T05:00:00+01:00"), in: rome)
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
    // Monday's hours end as Tuesday's begin. Nothing changes at that boundary, but it's still the next one.
    #expect(weekdays.nextBoundary(after: moment("2026-11-30T10:00:00+01:00"), in: rome)
        == moment("2026-12-01T00:00:00+01:00"))
}

@Test func hoursThatBeganTheDayBeforeCanStillBeGoingOn() {
    // 24 hours from 9:00, so at 8:00 on Tuesday, Monday's hours have another hour to go.
    let weekdays = WorkingHours(start: 9 * 60, end: 9 * 60, days: .mondayToFriday)
    #expect(weekdays.contains(moment("2026-12-01T08:00:00+01:00"), in: rome))
    #expect(weekdays.nextBoundary(after: moment("2026-12-01T08:00:00+01:00"), in: rome)
        == moment("2026-12-01T09:00:00+01:00"))
}

@Test func withoutDaysThereAreNoHours() {
    let never = WorkingHours(start: 9 * 60, end: 17 * 60, days: [])
    #expect(!never.contains(moment("2026-11-30T10:00:00+01:00"), in: rome))
    #expect(never.nextBoundary(after: moment("2026-11-30T10:00:00+01:00"), in: rome) == nil)
}

@Test func hoursAreAnHourShorterWhenTheClocksGoForward() {
    // The clock shows 4:00 two hours after 1:00, not three, so the end follows the clock rather than the hours
    // that pass.
    let sundayNight = WorkingHours(start: 1 * 60, end: 4 * 60, days: .sunday)
    #expect(sundayNight.nextBoundary(after: moment("2026-03-29T01:00:00+01:00"), in: rome)
        == moment("2026-03-29T04:00:00+02:00"))
    #expect(sundayNight.contains(moment("2026-03-29T03:30:00+02:00"), in: rome))
}

@Test func hoursThatStartAtASkippedTimeStartWhenTheClocksJumpPastIt() {
    // The clocks go from 1:59 to 3:00, so 2:30 never shows.
    let hours = WorkingHours(start: 2 * 60 + 30, end: 8 * 60, days: .sunday)
    #expect(!hours.contains(moment("2026-03-29T01:59:00+01:00"), in: rome))
    #expect(hours.contains(moment("2026-03-29T03:00:00+02:00"), in: rome))
    #expect(hours.nextBoundary(after: moment("2026-03-28T22:00:00+01:00"), in: rome)
        == moment("2026-03-29T03:00:00+02:00"))
}

@Test func overnightHoursFollowTheClocksIntoTheNextDay() {
    // From Saturday 22:00 to Sunday 6:00 the clocks go forward, so the end is 6:00 summer time.
    let saturdayNight = WorkingHours(start: 22 * 60, end: 6 * 60, days: .saturday)
    #expect(saturdayNight.nextBoundary(after: moment("2026-03-28T23:00:00+01:00"), in: rome)
        == moment("2026-03-29T06:00:00+02:00"))
}

@Test func hoursAreAnHourLongerWhenTheClocksGoBack() {
    // The clock shows 6:00 seven hours after midnight, as it shows 2:00 to 2:59 twice.
    let sundayNight = WorkingHours(start: 0, end: 6 * 60, days: .sunday)
    #expect(sundayNight.nextBoundary(after: moment("2026-10-25T00:00:00+02:00"), in: rome)
        == moment("2026-10-25T06:00:00+01:00"))
}

@Test func hoursThatStartAtARepeatedTimeStartTheFirstTime() {
    // 2:30 shows in summer time, then an hour later in winter time.
    let hours = WorkingHours(start: 2 * 60 + 30, end: 8 * 60, days: .sunday)
    #expect(hours.nextBoundary(after: moment("2026-10-25T00:00:00+02:00"), in: rome)
        == moment("2026-10-25T02:30:00+02:00"))
    // When the clocks go back, they show a time before the start again. The hours go on regardless.
    #expect(hours.contains(moment("2026-10-25T02:10:00+01:00"), in: rome))
    #expect(hours.nextBoundary(after: moment("2026-10-25T02:30:00+02:00"), in: rome)
        == moment("2026-10-25T08:00:00+01:00"))
}

@Test func hoursThatStartAtASkippedTimeStartTheSameDay() {
    // On Lord Howe Island the clocks go from 2:00 to 2:30 on Sunday 4 October 2026, so 2:15 never shows.
    // The hours start as the clocks jump, not at 2:15 the next day, which would also come after their end.
    let lordHowe = calendar(in: "Australia/Lord_Howe")
    let hours = WorkingHours(start: 2 * 60 + 15, end: 8 * 60, days: .sunday)
    #expect(hours.nextBoundary(after: moment("2026-10-03T22:00:00+10:30"), in: lordHowe)
        == moment("2026-10-04T02:30:00+11:00"))
    #expect(!hours.contains(moment("2026-10-04T01:59:00+10:30"), in: lordHowe))
    #expect(hours.contains(moment("2026-10-04T02:30:00+11:00"), in: lordHowe))
    #expect(hours.nextBoundary(after: moment("2026-10-04T02:30:00+11:00"), in: lordHowe)
        == moment("2026-10-04T08:00:00+11:00"))
}

@Test func hoursThatTheClocksSkipEntirelyDoNotHappen() {
    // Both 2:05 and 2:35 fall in the hour that Rome skips on 29 March, so that Sunday has no hours, and the next
    // ones are a week later.
    let hours = WorkingHours(start: 2 * 60 + 5, end: 2 * 60 + 35, days: .sunday)
    #expect(!hours.contains(moment("2026-03-29T03:00:00+02:00"), in: rome))
    #expect(hours.nextBoundary(after: moment("2026-03-28T22:00:00+01:00"), in: rome)
        == moment("2026-04-05T02:05:00+02:00"))
}

@Test func hoursThatStartAtASkippedMidnightStartWithTheDay() {
    // In Santiago, Sunday 6 September 2026 begins at 1:00, as the clocks go from 23:59 straight to 1:00.
    let santiago = calendar(in: "America/Santiago")
    let hours = WorkingHours(start: 0, end: 6 * 60, days: .sunday)
    #expect(hours.nextBoundary(after: moment("2026-09-05T23:00:00-04:00"), in: santiago)
        == moment("2026-09-06T01:00:00-03:00"))
}
