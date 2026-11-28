import BradipoCore
import Testing

@Test func draftSplitsALengthIntoMinutesAndSeconds() {
    let draft = DurationDraft(25 * 60 + 5)
    #expect(draft.minutes == "25")
    #expect(draft.seconds == "5")
    #expect(draft.duration == 25 * 60 + 5)
}

@Test func numbersBeyondAFieldsRangeAreHeldToIt() {
    // Each field keeps to its own range rather than carrying 75 seconds into a minute,
    // so what's saved is the limit that was hit.
    #expect(DurationDraft(minutes: "120", seconds: "30").duration == 99 * 60 + 30)
    #expect(DurationDraft(minutes: "1", seconds: "75").duration == 60 + 59)
    #expect(DurationDraft(minutes: "-5", seconds: "30").duration == 30)
}

@Test func bothFieldsAtTheirLimitsAreTheLongestLength() {
    // 99:59 is the longest length the timer runs, so holding each number to its range mustn't cut it short.
    #expect(DurationDraft(minutes: "99", seconds: "59").duration == 99 * 60 + 59)
}

@Test func oneSecondIsALength() {
    // Only 0:00 is turned away, so the shortest length the timer runs can still be typed.
    #expect(DurationDraft(minutes: "0", seconds: "1").duration == 1)
}

@Test func anEmptyFieldCountsAsZero() {
    // Someone after a length under a minute can clear the minutes instead of typing 0.
    #expect(DurationDraft(minutes: "", seconds: "30").duration == 30)
    #expect(DurationDraft(minutes: "2", seconds: "").duration == 120)
}

@Test func spacesAroundANumberAreIgnored() {
    // A pasted number can bring spaces with it, or the line break after it when a whole line is copied.
    #expect(DurationDraft(minutes: " 5 ", seconds: "0").duration == 300)
    #expect(DurationDraft(minutes: "5\n", seconds: "0").duration == 300)
}

@Test func zeroIsNotALength() {
    // The timer would run 0:00 as 0:01 and start a break at once, so the row keeps the saved length instead.
    #expect(DurationDraft(minutes: "0", seconds: "0").duration == nil)
    #expect(DurationDraft(minutes: "", seconds: "").duration == nil)
}

@Test func textThatIsNotAWholeNumberIsNotALength() {
    // There's no number to hold to the range, so the row keeps the saved length.
    #expect(DurationDraft(minutes: "five", seconds: "0").duration == nil)
    #expect(DurationDraft(minutes: "1.5", seconds: "0").duration == nil)
    #expect(DurationDraft(minutes: "1", seconds: "3o").duration == nil)
}

@Test func aLengthUnderAMinuteIsTitledInSeconds() {
    #expect(DurationDraft.title(20) == "20 sec")
}

@Test func wholeMinutesAreTitledWithoutSeconds() {
    // A typed 1:00 reads like the presets, such as "5 min", rather than "1 min 0 sec".
    #expect(DurationDraft.title(60) == "1 min")
}

@Test func aLengthWithMinutesAndSecondsIsTitledWithBoth() {
    // A typed length shows the units the fields have, rather than "450 sec".
    #expect(DurationDraft.title(450) == "7 min 30 sec")
}

@Test func theLongestLengthIsTitledInFull() {
    // Minutes go past 59 rather than into hours, as in the minutes field.
    #expect(DurationDraft.title(99 * 60 + 59) == "99 min 59 sec")
}
