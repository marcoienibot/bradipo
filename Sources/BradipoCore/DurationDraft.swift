import Foundation

/// The minutes and seconds typed into a settings row for a length that isn't a preset.
///
/// The row saves the length only once the person is done with both fields. Saving each field on its own
/// would run lengths nobody asked for, such as 0:00 on the way from 1:00 to 0:30.
public struct DurationDraft: Equatable, Sendable {
    public var minutes: String
    public var seconds: String

    /// The fields showing a length in seconds.
    public init(_ duration: Int) {
        minutes = String(duration / 60)
        seconds = String(duration % 60)
    }

    public init(minutes: String, seconds: String) {
        self.minutes = minutes
        self.seconds = seconds
    }

    /// The length in seconds the fields ask for. A number outside its field's range is held to it, so a slip such as
    /// 120 minutes saves the limit that was hit, which the pop-up then shows. An empty field counts as 0, as its
    /// placeholder shows.
    /// It's nil for text that isn't a whole number, for a number too big for `Int` such as twenty 9s, and for 0:00,
    /// so the row keeps the saved length.
    public var duration: Int? {
        guard let minutes = Self.number(minutes, in: 0...99), let seconds = Self.number(seconds, in: 0...59),
              minutes + seconds > 0 else { return nil }
        return minutes * 60 + seconds
    }

    /// A length in the units of the fields, such as "7 min 30 sec", for the pop-up beside them.
    public static func title(_ duration: Int) -> String {
        switch (duration / 60, duration % 60) {
        case let (0, seconds): "\(seconds) sec"
        case let (minutes, 0): "\(minutes) min"
        case let (minutes, seconds): "\(minutes) min \(seconds) sec"
        }
    }

    private static func number(_ text: String, in range: ClosedRange<Int>) -> Int? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = text.isEmpty ? 0 : Int(text) else { return nil }
        return min(range.upperBound, max(range.lowerBound, number))
    }
}
