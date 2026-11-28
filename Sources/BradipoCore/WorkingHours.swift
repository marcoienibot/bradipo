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
/// A time the clocks skip takes effect when they jump past it, and a time they repeat takes effect the first time.
public struct WorkingHours: Equatable, Sendable {
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

    /// The first moment after `date` at which the hours begin or end. It's nil if they never do: with no days,
    /// or when every day's hours begin as the day before's end.
    public func nextChange(after date: Date, in calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: date)
        // The end of the hours that `date` is in, once they're found.
        var end: Date?
        // The hours that began yesterday can still be going on, and with a single day chosen, the next begin a week
        // after today's.
        for offset in -1...7 {
            let hours = calendar.date(byAdding: .day, value: offset, to: today)
                .flatMap { interval(startingOn: $0, in: calendar) }
            if let current = end {
                // Hours that begin as the earlier ones end carry them on.
                guard let hours, hours.lowerBound <= current else { return current }
                end = hours.upperBound
            } else if let hours, hours.contains(date) {
                end = hours.upperBound
            } else if let hours, hours.lowerBound > date {
                return hours.lowerBound
            }
        }
        return nil
    }

    /// The hours that start on the day of `day`, if it's one of the chosen days.
    private func interval(startingOn day: Date, in calendar: Calendar) -> Range<Date>? {
        guard days.contains(DaysOfWeek(weekday: calendar.component(.weekday, from: day))),
              let endDay = end > start ? day : calendar.date(byAdding: .day, value: 1, to: day),
              let from = Self.moment(start, on: day, in: calendar),
              let to = Self.moment(end, on: endDay, in: calendar) else { return nil }
        return from..<to
    }

    /// When the clock on that day first shows the time, or jumps past it.
    private static func moment(_ minutes: Int, on day: Date, in calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day,
                      matchingPolicy: .nextTime, repeatedTimePolicy: .first)
    }
}
