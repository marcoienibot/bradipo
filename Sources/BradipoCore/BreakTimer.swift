import Foundation

public enum ActivityState: Equatable, Sendable {
    case active
    case meeting
    case unavailable
}

public enum PauseReason: Equatable, Sendable {
    case manual, outsideWorkingHours, meeting, unavailable
}

public enum BreakPhase: Equatable, Sendable {
    case working, resting
}

public enum BreakKind: Sendable {
    case short, long
}

/// A change that `BreakTimer.tick` makes as time passes, rather than one the caller asks for.
public enum BreakTransition: Equatable, Sendable {
    /// A break came due and began, possibly after a meeting deferred it.
    case started
    /// A break ran its full length. Time away also ends a break, but that isn't a finish.
    case finished
}

public struct BreakTimer: Sendable {
    public static let defaultLongBreakDuration: TimeInterval = 5 * 60
    public static let defaultShortBreaksBeforeLongBreak = 3

    public var phase: BreakPhase { activeBreak == nil ? .working : .resting }
    /// The current break while resting, or the next scheduled break while working.
    public var breakKind: BreakKind {
        activeBreak?.kind ?? (shortBreaksRemaining == 0 ? .long : .short)
    }
    public private(set) var isManuallyPaused = false
    public private(set) var workDuration: TimeInterval
    /// The short break length, including preferences saved before long breaks were introduced.
    public private(set) var breakDuration: TimeInterval
    public private(set) var longBreakDuration: TimeInterval
    public private(set) var shortBreaksBeforeLongBreak: Int
    /// While off, every break is short and none count toward a long break, so turning
    /// long breaks back on starts a new cycle. A long break already in progress keeps running.
    public private(set) var longBreaksEnabled: Bool
    /// Excludes a short break already in progress. A long break starts a new cycle.
    public var shortBreaksRemaining: Int { max(0, shortBreaksBeforeLongBreak - shortBreaksTaken) }
    public var remainingSeconds: Int { Int(ceil(remaining)) }
    public var formattedRemainingTime: String {
        Self.formatted(seconds: remainingSeconds, duration: activeBreak?.duration ?? workDuration)
    }
    /// Also supplies the natural banner width between breaks.
    public var formattedBreakTime: String {
        if activeBreak != nil { return formattedRemainingTime }
        let duration = length(of: breakKind)
        return Self.formatted(seconds: Int(ceil(duration)), duration: duration)
    }

    private static func formatted(seconds: Int, duration: TimeInterval) -> String {
        let format = ceil(duration) < 10 * 60 ? "%d:%02d" : "%02d:%02d"
        return String(format: format, seconds / 60, seconds % 60)
    }
    public var timeUntilNextDisplayedSecond: TimeInterval { remaining - Double(remainingSeconds - 1) }
    public var timeUntilNextTick: TimeInterval? {
        switch pauseReason {
        // A headset playing output can stay running when its input stops,
        // so a due break needs to recheck even without a device notification.
        case .meeting: 0.25
        case nil: timeUntilNextDisplayedSecond
        // Resuming from the menu ticks, notifications report the end of each away state,
        // and the app wakes when working hours begin.
        case .manual, .outsideWorkingHours, .unavailable: nil
        }
    }
    public var pauseReason: PauseReason? {
        guard phase == .working else { return nil }
        if isManuallyPaused { return .manual }
        if outsideWorkingHours { return .outsideWorkingHours }
        return switch activity {
        case .active: nil
        case .meeting: remaining == 0 ? .meeting : nil
        case .unavailable: .unavailable
        }
    }

    /// Also outside working hours, which only keep breaks from coming due.
    public var canStartBreak: Bool {
        phase == .working && !isManuallyPaused && activity == .active
    }

    /// Whether a tick at `now` would start a break unless a meeting holds it, so the activity sampled for that tick
    /// decides the break. A break that a meeting holds stays due.
    public func isBreakDue(at now: TimeInterval) -> Bool {
        // A trial tick on a copy can't drift from what `tick` does.
        var trial = self
        return trial.tick(at: now, activity: .active) == .started
    }

    private var shortBreaksTaken = 0
    private var activeBreak: (kind: BreakKind, duration: TimeInterval)?
    private func length(of kind: BreakKind) -> TimeInterval { kind == .long ? longBreakDuration : breakDuration }
    private var remaining: TimeInterval
    private var lastTick: TimeInterval
    private var activity: ActivityState = .active
    private var outsideWorkingHours = false

    public init(workDuration: TimeInterval, breakDuration: TimeInterval,
                longBreakDuration: TimeInterval = Self.defaultLongBreakDuration,
                shortBreaksBeforeLongBreak: Int = Self.defaultShortBreaksBeforeLongBreak,
                longBreaksEnabled: Bool = true, now: TimeInterval) {
        precondition(workDuration >= 1 && breakDuration >= 1 && longBreakDuration >= 1 && shortBreaksBeforeLongBreak >= 1)
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longBreakDuration
        self.shortBreaksBeforeLongBreak = shortBreaksBeforeLongBreak
        self.longBreaksEnabled = longBreaksEnabled
        remaining = workDuration
        lastTick = now
    }

    /// Supply monotonic timestamps and sample the environment before deciding a break is due.
    ///
    /// Outside working hours no break comes due, and the work interval waits at its full length, so a fresh one
    /// starts when they begin. A break that's running when they end still finishes.
    @discardableResult
    public mutating func tick(at now: TimeInterval, activity newActivity: ActivityState,
                              withinWorkingHours: Bool = true) -> BreakTransition? {
        let wasPaused = pauseReason != nil
        let elapsed = max(0, now - lastTick)
        lastTick = max(lastTick, now)
        activity = newActivity
        outsideWorkingHours = !withinWorkingHours

        switch phase {
        case .working:
            if activity == .unavailable || outsideWorkingHours {
                remaining = workDuration
            } else if pauseReason == nil {
                if !wasPaused { remaining = max(0, remaining - elapsed) }
                if remaining == 0 { startBreak(at: now) }
            }
            return phase == .resting ? .started : nil
        case .resting:
            remaining -= elapsed
            guard remaining <= 0 || activity == .unavailable else { return nil }
            endBreak(at: now)
            return activity == .unavailable ? nil : .finished
        }
    }

    public mutating func restart(at now: TimeInterval) {
        remaining = activeBreak?.duration ?? workDuration
        isManuallyPaused = false
        lastTick = now
    }

    public mutating func endBreak(at now: TimeInterval) {
        guard phase == .resting else { return }
        activeBreak = nil
        restart(at: now)
    }

    public mutating func setManuallyPaused(_ paused: Bool, at now: TimeInterval) {
        guard phase == .working, paused != isManuallyPaused else { return }
        isManuallyPaused = paused
        lastTick = now
    }

    public mutating func startBreak(at now: TimeInterval) {
        start(breakKind, at: now)
    }

    /// Starts a long break even while a short one is next, which starts a new cycle.
    /// Does nothing while long breaks are off.
    public mutating func startLongBreak(at now: TimeInterval) {
        guard longBreaksEnabled else { return }
        start(.long, at: now)
    }

    private mutating func start(_ kind: BreakKind, at now: TimeInterval) {
        guard canStartBreak else { return }
        let duration = length(of: kind)
        activeBreak = (kind, duration)
        shortBreaksTaken = kind == .short && longBreaksEnabled ? shortBreaksTaken + 1 : 0
        remaining = duration
        lastTick = now
    }

    public mutating func configure(
        workDuration: TimeInterval, breakDuration: TimeInterval,
        longBreakDuration: TimeInterval? = nil, shortBreaksBeforeLongBreak: Int? = nil,
        longBreaksEnabled: Bool? = nil, at now: TimeInterval
    ) {
        let longDuration = longBreakDuration ?? self.longBreakDuration
        let shortCount = shortBreaksBeforeLongBreak ?? self.shortBreaksBeforeLongBreak
        precondition(workDuration >= 1 && breakDuration >= 1 && longDuration >= 1 && shortCount >= 1)
        if phase == .working && self.workDuration != workDuration {
            remaining = workDuration
            lastTick = now
        }
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.longBreakDuration = longDuration
        self.shortBreaksBeforeLongBreak = shortCount
        self.longBreaksEnabled = longBreaksEnabled ?? self.longBreaksEnabled
        if !self.longBreaksEnabled { shortBreaksTaken = 0 }
    }
}
