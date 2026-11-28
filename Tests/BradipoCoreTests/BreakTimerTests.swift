import BradipoCore
import Testing

@Test func countdownWidthFollowsTheStartingDurationOfEachInterval() {
    var timer = BreakTimer(workDuration: 600, breakDuration: 599, now: 0)
    #expect(timer.formattedRemainingTime == "10:00")
    timer.tick(at: 1, activity: .active)
    #expect(timer.formattedRemainingTime == "09:59")
    timer.startBreak(at: 1)
    #expect(timer.formattedRemainingTime == "9:59")

    // New settings apply to future intervals while the active break keeps its original width.
    timer.configure(workDuration: 300, breakDuration: 600, at: 1)
    timer.tick(at: 595, activity: .active)
    #expect(timer.formattedRemainingTime == "0:05")
    timer.tick(at: 600, activity: .active)
    #expect(timer.formattedRemainingTime == "5:00")
    timer.startBreak(at: 600)
    timer.tick(at: 601, activity: .active)
    #expect(timer.formattedRemainingTime == "09:59")
}

@Test func meetingAtDeadlineDefersOneFullBreakUntilRelease() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 19, activity: .active)
    #expect(timer.tick(at: 20, activity: .meeting) == nil)
    timer.startBreak(at: 20)
    #expect(timer.phase == .working)
    #expect(timer.pauseReason == .meeting)
    #expect(timer.remainingSeconds == 0)

    #expect(timer.tick(at: 3620, activity: .meeting) == nil)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 0)

    #expect(timer.tick(at: 3620.25, activity: .active) == .started)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 5)
    #expect(timer.tick(at: 3625.25, activity: .active) == .finished)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 20)
}

@Test func dictationCountsTowardTheOriginalWorkDeadline() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 3.75, activity: .active)
    timer.tick(at: 4, activity: .meeting)
    timer.startBreak(at: 4)
    timer.tick(at: 9, activity: .meeting)
    #expect(timer.phase == .working)
    #expect(timer.pauseReason == nil)
    #expect(timer.remainingSeconds == 11)

    timer.tick(at: 11.125, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 9)
    #expect(timer.timeUntilNextDisplayedSecond == 0.875)
    timer.tick(at: 20, activity: .active)
    #expect(timer.phase == .resting)
}

@Test func manualPauseHoldsAnOverdueBreakAndSleepClearsIt() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 25, activity: .meeting)
    timer.setManuallyPaused(true, at: 25)
    timer.tick(at: 30, activity: .active)
    #expect(timer.pauseReason == .manual)
    #expect(timer.remainingSeconds == 0)

    timer.setManuallyPaused(false, at: 35)
    timer.tick(at: 35, activity: .meeting)
    #expect(timer.pauseReason == .meeting)
    timer.tick(at: 36, activity: .unavailable)
    timer.tick(at: 100, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 20)
}

@Test func elapsedTimeAndThePauseActionDuringARest() {
    var timer = BreakTimer(workDuration: 120, breakDuration: 90, now: 100)
    timer.tick(at: 111.6, activity: .active)
    #expect(timer.remainingSeconds == 109)
    timer.startBreak(at: 112)

    // The menu's pause action is ignored during a break, so the rest still ends on schedule.
    timer.setManuallyPaused(true, at: 173)
    timer.tick(at: 201, activity: .active)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 1)
    timer.tick(at: 202, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 120)
}

@Test(arguments: [ActivityState.active, .meeting])
func meetingDuringBreakPreservesItsDeadline(activityAtEnd: ActivityState) {
    var timer = BreakTimer(workDuration: 60, breakDuration: 20, now: 0)
    timer.tick(at: 60, activity: .active)
    timer.tick(at: 68, activity: .meeting)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 12)

    // A short dictation can end during the break, while a call can outlast it.
    timer.tick(at: 79, activity: activityAtEnd)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 1)
    #expect(timer.tick(at: 80, activity: activityAtEnd) == .finished)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 60)
    timer.tick(at: 81, activity: activityAtEnd)
    #expect(timer.remainingSeconds == 59)
}

@Test func clearsExistingBreakWhenMacBecomesUnavailable() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 10, now: 100)
    timer.startBreak(at: 100)
    timer.tick(at: 104, activity: .unavailable)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 20)
    timer.tick(at: 108, activity: .active)
    #expect(timer.remainingSeconds == 20)
}

@Test(arguments: [false, true])
func unavailableMacWaitsForWakeBeforeSchedulingMoreTicks(manuallyPaused: Bool) {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 7, activity: .active)
    timer.setManuallyPaused(manuallyPaused, at: 7)
    timer.tick(at: 8, activity: .unavailable)
    #expect(timer.timeUntilNextTick == nil)

    // Wake is the first sample after a long absence, even if manual pause
    // took precedence over the away message in the menu.
    timer.tick(at: 3608, activity: .active)
    #expect(timer.remainingSeconds == 20)
    // Only the countdown needs a timer. Resuming from the menu ticks on its own.
    #expect(timer.timeUntilNextTick == (manuallyPaused ? nil : 1))
    timer.tick(at: 3609, activity: .active)
    #expect(timer.remainingSeconds == (manuallyPaused ? 20 : 19))
}

@Test func resumeRespectsEnvironmentAndSleepResetsWork() {
    var timer = BreakTimer(workDuration: 100, breakDuration: 20, now: 0)
    timer.tick(at: 95, activity: .active)
    timer.setManuallyPaused(true, at: 95)
    timer.tick(at: 110, activity: .meeting)
    timer.setManuallyPaused(false, at: 111)
    #expect(!timer.canStartBreak)
    #expect(timer.remainingSeconds == 5)

    timer.tick(at: 150, activity: .unavailable)
    timer.tick(at: 4600, activity: .active)
    #expect(timer.pauseReason == nil)
    #expect(timer.remainingSeconds == 100)
}

@Test func changesToDurationApplyToTheNextRest() {
    var timer = BreakTimer(workDuration: 120, breakDuration: 20, now: 0)
    timer.startBreak(at: 2)
    timer.configure(workDuration: 60, breakDuration: 5, at: 7)
    timer.tick(at: 12, activity: .active)
    #expect(timer.remainingSeconds == 10)
    timer.tick(at: 22, activity: .active)
    #expect(timer.remainingSeconds == 60)
    timer.tick(at: 82, activity: .active)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 5)
}

@Test func restartingDuringABreakRestoresItsFullDuration() {
    var timer = BreakTimer(workDuration: 120, breakDuration: 20, now: 0)
    timer.startBreak(at: 65)
    timer.tick(at: 72, activity: .active)
    // A length change is for the next break. This break still lasts 20 seconds.
    timer.configure(workDuration: 120, breakDuration: 30, at: 72)
    timer.restart(at: 73)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 20)

    timer.tick(at: 85, activity: .active)
    #expect(timer.remainingSeconds == 8)
    timer.tick(at: 93, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 120)
}

@Test func stoppingABreakStartsAFreshWorkInterval() {
    var timer = BreakTimer(workDuration: 120, breakDuration: 20, now: 0)
    timer.startBreak(at: 65)
    timer.endBreak(at: 73)

    // The original break deadline must not end the new work interval.
    timer.tick(at: 85, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 108)
}

@Test func restartDuringAMeetingClearsThePendingBreak() {
    var timer = BreakTimer(workDuration: 120, breakDuration: 20, now: 0)
    timer.tick(at: 120, activity: .meeting)
    #expect(timer.pauseReason == .meeting)
    timer.setManuallyPaused(true, at: 121)
    timer.restart(at: 130)
    #expect(timer.pauseReason == nil)
    #expect(timer.remainingSeconds == 120)
    timer.tick(at: 135, activity: .meeting)
    #expect(timer.remainingSeconds == 115)
    timer.tick(at: 140, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 110)
}

@Test func twoShortBreaksThenALongBreakRepeatAcrossWorkIntervals() {
    var timer = BreakTimer(workDuration: 10, breakDuration: 2, longBreakDuration: 8,
                           shortBreaksBeforeLongBreak: 2, now: 0)
    #expect(timer.shortBreaksRemaining == 2)
    timer.tick(at: 10, activity: .active)
    #expect(timer.shortBreaksRemaining == 1)
    #expect(timer.breakKind == .short)
    #expect(timer.remainingSeconds == 2)
    timer.tick(at: 12, activity: .active)
    timer.tick(at: 22, activity: .active)
    #expect(timer.shortBreaksRemaining == 0)
    #expect(timer.breakKind == .short)
    #expect(timer.remainingSeconds == 2)
    timer.tick(at: 24, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.breakKind == .long)
    #expect(timer.formattedBreakTime == "0:08")

    // A meeting defers the due long break without consuming its slot.
    timer.tick(at: 34, activity: .meeting)
    timer.startBreak(at: 35)
    #expect(timer.shortBreaksRemaining == 0)
    #expect(timer.phase == .working)
    #expect(timer.pauseReason == .meeting)
    timer.tick(at: 40, activity: .active)
    #expect(timer.shortBreaksRemaining == 2)
    #expect(timer.phase == .resting)
    #expect(timer.breakKind == .long)
    #expect(timer.remainingSeconds == 8)
    timer.tick(at: 48, activity: .active)
    timer.tick(at: 58, activity: .active)
    #expect(timer.breakKind == .short)
    #expect(timer.remainingSeconds == 2)
}

@Test func aLongBreakTakenWhileAShortOneIsNextRunsForTheLongLength() {
    // 90 s rather than the 300 s default, so a break that ignored the setting would fail.
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 90,
                           shortBreaksBeforeLongBreak: 2, now: 0)
    #expect(timer.breakKind == .short)
    timer.startLongBreak(at: 5)
    #expect(timer.phase == .resting)
    #expect(timer.breakKind == .long)
    #expect(timer.remainingSeconds == 90)

    // A short break would have ended at 15 s. This one ends 90 s after it started.
    timer.tick(at: 94, activity: .active)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 1)
    #expect(timer.tick(at: 95, activity: .active) == .finished)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 60)
}

@Test func aLongBreakTakenWhileAShortOneIsNextStartsANewCycle() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 2, now: 0)
    timer.startBreak(at: 0)
    timer.endBreak(at: 1)
    #expect(timer.shortBreaksRemaining == 1)

    // The short break taken before it no longer counts, so both short breaks come before the next long one.
    timer.startLongBreak(at: 2)
    #expect(timer.shortBreaksRemaining == 2)
    timer.endBreak(at: 3)
    #expect(timer.breakKind == .short)
    timer.startBreak(at: 4)
    timer.endBreak(at: 5)
    #expect(timer.breakKind == .short)
    timer.startBreak(at: 6)
    timer.endBreak(at: 7)
    #expect(timer.breakKind == .long)
}

@Test func aLongBreakCannotStartWhileRemindersArePaused() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 3, now: 0)
    timer.startBreak(at: 0)
    timer.endBreak(at: 1)
    timer.setManuallyPaused(true, at: 2)
    timer.startLongBreak(at: 3)
    #expect(timer.phase == .working)
    // The ignored request leaves the cycle alone, so the short break already taken still counts.
    #expect(timer.shortBreaksRemaining == 2)
}

@Test func aLongBreakCannotStartDuringAShortBreak() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 3, now: 0)
    timer.startBreak(at: 4)
    timer.startLongBreak(at: 5)
    // The short break isn't lengthened, and it still counts toward the cycle rather than starting a new one.
    #expect(timer.breakKind == .short)
    #expect(timer.remainingSeconds == 10)
    #expect(timer.shortBreaksRemaining == 2)

    // The request doesn't restart the short break either: that would move its end from 14 s to 15 s.
    #expect(timer.tick(at: 14, activity: .active) == .finished)
}

@Test func aLongBreakCannotStartWhileLongBreaksAreOff() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 2, longBreaksEnabled: false, now: 0)
    timer.tick(at: 20, activity: .active)
    // While long breaks are off every break is short, so the request is ignored.
    timer.startLongBreak(at: 20)
    #expect(timer.phase == .working)
    // The 20 s already worked still count, so the work interval doesn't start over.
    #expect(timer.remainingSeconds == 40)
}

@Test func editingTheFrequencyRecountsTheShortBreaksStillToCome() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, shortBreaksBeforeLongBreak: 3, now: 0)
    timer.startBreak(at: 1)
    timer.endBreak(at: 2)
    timer.startBreak(at: 3)

    // Two short breaks have started, so lowering the target to one makes the long break next.
    timer.configure(workDuration: 60, breakDuration: 10, shortBreaksBeforeLongBreak: 1, at: 4)
    #expect(timer.shortBreaksRemaining == 0)
    timer.endBreak(at: 5)
    #expect(timer.breakKind == .long)

    // Raising the target again preserves both short breaks already taken.
    timer.configure(workDuration: 60, breakDuration: 10, shortBreaksBeforeLongBreak: 4, at: 6)
    #expect(timer.shortBreaksRemaining == 2)
    #expect(timer.breakKind == .short)
}

@Test func frequencyAndLengthEditsPreserveProgressAndTheActiveBreak() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 600,
                           shortBreaksBeforeLongBreak: 3, now: 0)
    timer.startBreak(at: 0)
    timer.endBreak(at: 1)
    timer.tick(at: 20, activity: .active)

    // Lowering the count after the first short break makes the next break long.
    timer.configure(workDuration: 60, breakDuration: 10, shortBreaksBeforeLongBreak: 1, at: 20)
    #expect(timer.remainingSeconds == 41)
    #expect(timer.breakKind == .long)
    #expect(timer.formattedBreakTime == "10:00")
    timer.startBreak(at: 20)
    timer.configure(workDuration: 60, breakDuration: 10, longBreakDuration: 90, at: 21)
    timer.tick(at: 21, activity: .active)
    #expect(timer.formattedBreakTime == "09:59")
    timer.restart(at: 22)
    #expect(timer.breakKind == .long)
    #expect(timer.remainingSeconds == 600)

    // Stopping early or sleeping ends exactly one slot, just like natural expiry.
    timer.endBreak(at: 23)
    timer.startBreak(at: 24)
    #expect(timer.breakKind == .short)
    timer.tick(at: 25, activity: .unavailable)
    timer.tick(at: 80, activity: .active)
    timer.startBreak(at: 80)
    #expect(timer.breakKind == .long)
    #expect(timer.remainingSeconds == 90)
}

@Test func timeAwayDuringWorkKeepsTheNextLongBreak() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 1, now: 0)
    timer.startBreak(at: 0)
    timer.endBreak(at: 10)
    timer.tick(at: 30, activity: .active)
    #expect(timer.remainingSeconds == 40)

    // Sleeping from 30 s until 700 s restarts the work interval but not the cycle.
    timer.tick(at: 30, activity: .unavailable)
    timer.tick(at: 700, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 60)
    #expect(timer.breakKind == .long)

    timer.tick(at: 760, activity: .active)
    #expect(timer.phase == .resting)
    #expect(timer.breakKind == .long)
    #expect(timer.remainingSeconds == 300)
}

@Test func withLongBreaksOffEveryBreakIsShort() {
    var timer = BreakTimer(workDuration: 10, breakDuration: 2, longBreakDuration: 8,
                           shortBreaksBeforeLongBreak: 1, longBreaksEnabled: false, now: 0)
    for cycle in 0..<4 {
        let start = Double(cycle) * 12
        #expect(timer.breakKind == .short)
        #expect(timer.formattedBreakTime == "0:02")
        timer.tick(at: start + 10, activity: .active)
        #expect(timer.phase == .resting)
        #expect(timer.breakKind == .short)
        #expect(timer.remainingSeconds == 2)
        timer.tick(at: start + 12, activity: .active)
        #expect(timer.phase == .working)
    }
}

@Test func turningLongBreaksOffMidCycleAndBackOnStartsANewCycle() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 2, now: 0)
    timer.startBreak(at: 0)
    timer.endBreak(at: 1)
    timer.startBreak(at: 2)
    timer.endBreak(at: 3)
    #expect(timer.breakKind == .long)

    // The due long break becomes short, and short breaks stop counting toward one.
    timer.configure(workDuration: 60, breakDuration: 10, longBreaksEnabled: false, at: 4)
    #expect(timer.shortBreaksRemaining == 2)
    #expect(timer.breakKind == .short)
    timer.startBreak(at: 4)
    #expect(timer.remainingSeconds == 10)
    timer.endBreak(at: 5)
    timer.startBreak(at: 6)

    // Turning long breaks back on during a short break counts neither that break nor earlier ones.
    timer.configure(workDuration: 60, breakDuration: 10, longBreaksEnabled: true, at: 7)
    #expect(timer.shortBreaksRemaining == 2)
    timer.endBreak(at: 8)
    #expect(timer.breakKind == .short)
    timer.startBreak(at: 9)
    timer.endBreak(at: 10)
    timer.startBreak(at: 11)
    timer.endBreak(at: 12)
    #expect(timer.breakKind == .long)
}

@Test func turningLongBreaksOffAndBackOnBetweenBreaksStartsANewCycle() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 2, now: 0)
    timer.startBreak(at: 0)
    timer.endBreak(at: 1)
    timer.startBreak(at: 2)
    timer.endBreak(at: 3)
    #expect(timer.breakKind == .long)

    timer.configure(workDuration: 60, breakDuration: 10, longBreaksEnabled: false, at: 4)
    timer.configure(workDuration: 60, breakDuration: 10, longBreaksEnabled: true, at: 5)
    #expect(timer.shortBreaksRemaining == 2)
    #expect(timer.breakKind == .short)
}

@Test func turningLongBreaksOffKeepsALongBreakInProgress() {
    var timer = BreakTimer(workDuration: 60, breakDuration: 10, longBreakDuration: 300,
                           shortBreaksBeforeLongBreak: 1, now: 0)
    timer.startBreak(at: 0)
    timer.endBreak(at: 1)
    timer.startBreak(at: 2)
    #expect(timer.breakKind == .long)

    timer.configure(workDuration: 60, breakDuration: 10, longBreaksEnabled: false, at: 3)
    timer.tick(at: 3, activity: .active)
    #expect(timer.phase == .resting)
    #expect(timer.breakKind == .long)
    #expect(timer.remainingSeconds == 299)
    timer.restart(at: 4)
    #expect(timer.remainingSeconds == 300)

    timer.tick(at: 304, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.breakKind == .short)
    timer.startBreak(at: 305)
    #expect(timer.remainingSeconds == 10)
    timer.tick(at: 315, activity: .active)
    #expect(timer.phase == .working)
    #expect(timer.breakKind == .short)
}

@Test func tickReportsEachBreakStartingAndRunningItsFullLength() {
    var timer = BreakTimer(workDuration: 10, breakDuration: 2, longBreakDuration: 5,
                           shortBreaksBeforeLongBreak: 1, now: 0)
    var reported: [Int: BreakTransition] = [:]
    for second in 1...27 {
        reported[second] = timer.tick(at: Double(second), activity: .active)
        if second == 22 { #expect(timer.breakKind == .long) }
    }
    #expect(reported == [10: .started, 12: .finished, 22: .started, 27: .finished])

    // A tick long overdue, say after the Mac was busy, starts the full break but doesn't also finish it.
    #expect(timer.tick(at: 100, activity: .active) == .started)
    #expect(timer.remainingSeconds == 2)
    #expect(timer.tick(at: 102, activity: .active) == .finished)
}

@Test func stoppingRestartingOrSteppingAwayDuringABreakIsNotAFinish() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.startBreak(at: 0)
    timer.restart(at: 3)
    #expect(timer.tick(at: 5, activity: .active) == nil)
    timer.endBreak(at: 6)
    #expect(timer.tick(at: 8, activity: .active) == nil)

    // Time away ends the break without a finish, even once its full length has passed.
    #expect(timer.tick(at: 26, activity: .active) == .started)
    #expect(timer.tick(at: 40, activity: .unavailable) == nil)
    #expect(timer.phase == .working)
    #expect(timer.tick(at: 100, activity: .active) == nil)
    #expect(timer.remainingSeconds == 20)
}

// The app checks for meetings more carefully on the ticks for which this is true.
@Test func breakIsDueAtTheEndOfTheWorkInterval() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 10, activity: .active)
    #expect(!timer.isBreakDue(at: 19.5))
    #expect(timer.isBreakDue(at: 20))
    timer.tick(at: 20, activity: .active)
    #expect(!timer.isBreakDue(at: 21))
}

@Test func breakHeldByAMeetingStaysDue() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 20, activity: .meeting)
    // Every later tick can start the held break.
    #expect(timer.isBreakDue(at: 20.25))
    #expect(timer.isBreakDue(at: 3600))
}

@Test func meetingBeforeTheDeadlineDoesNotDelayTheDueBreak() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    // A call that began mid-interval doesn't pause the countdown, so the break is due on time.
    // The tick at the deadline then needs a fresh meeting check, not this earlier reading.
    timer.tick(at: 10, activity: .meeting)
    #expect(!timer.isBreakDue(at: 19.5))
    #expect(timer.isBreakDue(at: 20))
}

@Test func pausedRemindersHaveNoBreakDue() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 10, activity: .active)
    timer.setManuallyPaused(true, at: 10)
    // The deadline passes on the clock, but a paused countdown can't start a break.
    #expect(!timer.isBreakDue(at: 30))
    // Resuming keeps the 10 seconds that were left.
    timer.setManuallyPaused(false, at: 30)
    #expect(!timer.isBreakDue(at: 39))
    #expect(timer.isBreakDue(at: 40))
}

@Test func firstTickAfterTimeAwayHasNoBreakDue() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 5, activity: .unavailable)
    // The old deadline has passed, but returning restarts the interval instead of starting a break.
    #expect(!timer.isBreakDue(at: 100))
    timer.tick(at: 100, activity: .active)
    #expect(!timer.isBreakDue(at: 119))
    #expect(timer.isBreakDue(at: 120))
}

@Test func outsideWorkingHoursTheCountdownWaitsAtTheFullWorkInterval() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 15, activity: .active)
    #expect(timer.remainingSeconds == 5)
    // At the deadline, the working hours of that tick decide whether the break would start, like they do for `tick`.
    #expect(timer.isBreakDue(at: 20, withinWorkingHours: true))
    #expect(!timer.isBreakDue(at: 20, withinWorkingHours: false))
    // The hours end with 5 seconds to go, which start over rather than run out.
    timer.tick(at: 16, activity: .active, withinWorkingHours: false)
    #expect(timer.pauseReason == .outsideWorkingHours)
    #expect(timer.remainingSeconds == 20)
    // Long after the old deadline, no break has come due.
    #expect(!timer.isBreakDue(at: 600, withinWorkingHours: false))
    #expect(timer.tick(at: 600, activity: .active, withinWorkingHours: false) == nil)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 20)
    // Nothing needs to tick. The app wakes when the hours begin.
    #expect(timer.timeUntilNextTick == nil)
}

@Test func aFreshWorkIntervalStartsWhenWorkingHoursBegin() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 0, activity: .active, withinWorkingHours: false)
    timer.tick(at: 3600, activity: .active)
    // The hour outside them doesn't count toward the interval.
    #expect(timer.pauseReason == nil)
    #expect(timer.remainingSeconds == 20)
    #expect(timer.timeUntilNextTick == 1)
    timer.tick(at: 3601, activity: .active)
    #expect(timer.remainingSeconds == 19)
    #expect(timer.tick(at: 3620, activity: .active) == .started)
}

@Test func aBreakRunningWhenWorkingHoursEndFinishesOnSchedule() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    #expect(timer.tick(at: 20, activity: .active) == .started)
    timer.tick(at: 22, activity: .active, withinWorkingHours: false)
    #expect(timer.phase == .resting)
    #expect(timer.remainingSeconds == 3)
    // It's a finish, unlike a break that time away ends, so its end sound can play.
    #expect(timer.tick(at: 25, activity: .active, withinWorkingHours: false) == .finished)
    #expect(timer.pauseReason == .outsideWorkingHours)
    #expect(timer.remainingSeconds == 20)
    #expect(timer.timeUntilNextTick == nil)
}

@Test func aBreakThatAMeetingHoldsAsWorkingHoursEndIsDropped() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 20, activity: .meeting)
    #expect(timer.pauseReason == .meeting)
    timer.tick(at: 30, activity: .meeting, withinWorkingHours: false)
    // The call ends after the hours do, and the held break doesn't start outside them.
    #expect(timer.tick(at: 40, activity: .active, withinWorkingHours: false) == nil)
    #expect(timer.phase == .working)
    #expect(timer.remainingSeconds == 20)
}

@Test func aBreakCanStillBeTakenOutsideWorkingHours() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 10, activity: .active, withinWorkingHours: false)
    // Only the breaks that come due are off, so the menu's break action still works.
    #expect(timer.canStartBreak)
    timer.startBreak(at: 10)
    #expect(timer.phase == .resting)
    #expect(timer.tick(at: 15, activity: .active, withinWorkingHours: false) == .finished)
    // Afterwards the countdown waits again.
    #expect(timer.pauseReason == .outsideWorkingHours)
    #expect(timer.remainingSeconds == 20)
}

@Test func pausingByHandLastsAcrossTheEndAndStartOfWorkingHours() {
    var timer = BreakTimer(workDuration: 20, breakDuration: 5, now: 0)
    timer.tick(at: 5, activity: .active)
    timer.setManuallyPaused(true, at: 5)
    // The pause shows rather than the hours, as only resuming ends it.
    timer.tick(at: 100, activity: .active, withinWorkingHours: false)
    #expect(timer.pauseReason == .manual)
    #expect(timer.remainingSeconds == 20)
    // The hours begin again. Reminders stay paused, with a fresh interval waiting.
    timer.tick(at: 200, activity: .active)
    #expect(timer.pauseReason == .manual)
    #expect(timer.remainingSeconds == 20)
    timer.setManuallyPaused(false, at: 300)
    timer.tick(at: 301, activity: .active)
    #expect(timer.remainingSeconds == 19)
}
