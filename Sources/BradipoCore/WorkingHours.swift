import Foundation

/// Days of the week, by the weekday numbers of `Calendar`: 1 for Sunday through 7 for Saturday.
public struct DaysOfWeek: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The day with this `Calendar` weekday number.
    public init(weekday: Int) {
        rawValue = 1 << (weekday - 1)
    }

    public static let sunday = Self(weekday: 1)
    public static let monday = Self(weekday: 2)
    public static let tuesday = Self(weekday: 3)
    public static let wednesday = Self(weekday: 4)
    public static let thursday = Self(weekday: 5)
    public static let friday = Self(weekday: 6)
    public static let saturday = Self(weekday: 7)
    public static let mondayToFriday: Self = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let everyDay: Self = [.mondayToFriday, .saturday, .sunday]
}

/// The same hours on each of the chosen days, during which breaks come due.
///
/// Hours that end at or before they start run past midnight, and the day they start on decides whether they apply:
/// 22:00 to 6:00 on Fridays covers Friday night, not Thursday night. Equal times cover 24 hours.
///
/// The times are on the wall clock, so the hours are an hour shorter or longer when the clocks change during them.
/// A time the clocks skip takes effect when they jump past it, even when they jump into the next day, and a time
/// they repeat takes effect the first time. When the clocks skip both times at once, there are no hours that day.
public struct WorkingHours: Sendable {
    /// Minutes after midnight.
    public var start: Int
    /// Minutes after midnight.
    public var end: Int
    public var days: DaysOfWeek

    public init(start: Int, end: Int, days: DaysOfWeek) {
        precondition((0..<24 * 60).contains(start) && (0..<24 * 60).contains(end))
        self.start = start
        self.end = end
        self.days = days
    }

    public func contains(_ date: Date, in calendar: Calendar) -> Bool {
        // Hours end by the next day, so only those that start on the date's day or the day before can contain it.
        let today = calendar.startOfDay(for: date)
        return [-1, 0].contains { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
                .flatMap { interval(startingOn: $0, in: calendar) }?.contains(date) == true
        }
    }

    /// The first moment after `date` at which the hours begin or end, or nil if there are none in the next two weeks.
    /// Where one day's hours end as the next day's begin, that moment is still a boundary, though nothing changes there.
    public func nextBoundary(after date: Date, in calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        // The hours that began yesterday can still be going on. A single chosen day can have no hours one week,
        // when a clock change swallows them, so the search reaches the week after.
        return (-1...14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .compactMap { interval(startingOn: $0, in: calendar) }
            .flatMap { [$0.lowerBound, $0.upperBound] }
            .filter { $0 > date }
            .min()
    }

    /// The hours that start on the day of `day`, if it's one of the chosen days.
    private func interval(startingOn day: Date, in calendar: Calendar) -> Range<Date>? {
        guard days.contains(DaysOfWeek(weekday: calendar.component(.weekday, from: day))),
              let endDay = end > start ? day : calendar.date(byAdding: .day, value: 1, to: day),
              let from = Self.moment(start, on: day, in: calendar),
              let to = Self.moment(end, on: endDay, in: calendar), from < to else { return nil }
        return from..<to
    }

    /// The first moment of that day at which the clock shows the time or later. When the clocks jump from before
    /// the time into the next day, as in Nuuk from 22:59:59 to 0:00, it's the jump, which is the next day's first moment.
    ///
    /// `Calendar.date(bySettingHour:…)` can't stand in: for a time the clocks skip, it can answer with a moment on
    /// a later day, such as the Monday after Lord Howe Island's clocks jump from 2:00 to 2:30 on a Sunday.
    private static func moment(_ minutes: Int, on day: Date, in calendar: Calendar) -> Date? {
        guard let dayInterval = calendar.dateInterval(of: .day, for: day) else { return nil }
        let target = TimeInterval(minutes * 60)
        var from = dayInterval.start
        while from < dayInterval.end {
            // Until the clocks change, the clock moves on with time, so it shows the time that long after `from`.
            // When it already shows a later time, the clocks jumped past the time at `from`. Despite its name,
            // `nextDaylightSavingTimeTransition` reports any change of offset, such as a time zone's new standard time.
            let clock = calendar.dateComponents([.hour, .minute, .second], from: from)
            let shown = TimeInterval((clock.hour ?? 0) * 3600 + (clock.minute ?? 0) * 60 + (clock.second ?? 0))
            let moment = from.addingTimeInterval(max(0, target - shown))
            guard let change = calendar.timeZone.nextDaylightSavingTimeTransition(after: from), change <= moment else {
                return min(moment, dayInterval.end)
            }
            from = change
        }
        return dayInterval.end
    }
}
