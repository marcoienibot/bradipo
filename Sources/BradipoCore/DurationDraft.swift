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

    /// The length in seconds the fields ask for, with each number held to its field's range, so the fields
    /// show the limit that was hit. An empty field counts as 0, as its placeholder shows.
    /// It's nil for text that isn't a whole number and for 0:00, so the row keeps the saved length.
    public var duration: Int? {
        guard let minutes = Self.number(minutes, in: 0...99), let seconds = Self.number(seconds, in: 0...59),
              minutes + seconds > 0 else { return nil }
        return minutes * 60 + seconds
    }

    private static func number(_ text: String, in range: ClosedRange<Int>) -> Int? {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard let number = text.isEmpty ? 0 : Int(text) else { return nil }
        return min(range.upperBound, max(range.lowerBound, number))
    }
}
