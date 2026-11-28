import AppKit
import BradipoCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var isOpeningOrTrackingMenu = false
    private let pauseStatus = NSMenuItem()
    private let takeBreak = NSMenuItem()
    private let takeLongBreak = NSMenuItem(title: "Take a Long Break", action: #selector(startBreak), keyEquivalent: "")
    private let pause = NSMenuItem()
    /// Both are off until turned on in Settings. They mark only the changes `BreakTimer.tick` reports, so starting or
    /// stopping a break from the menu or banner, or time away ending one, plays nothing.
    private let breakSounds: [(transition: BreakTransition, sound: BreakSound)] = [(.started, .start), (.finished, .end)]
    private lazy var settings = SettingsWindow(host: SettingsHost(
        overlay: overlay, login: LoginItem(), updater: Updater(),
        ignoredApps: Binding { @MainActor [weak self] in self?.ignoredApps ?? [:] } set: { @MainActor [weak self] in
            self?.ignoredApps = $0
        },
        apply: { [weak self] in self?.applySettings() },
        canResetBanners: { [weak self] in self.map { $0.overlay.canResetBanners(timer: $0.clock) } ?? false }
    ))
    private lazy var overlay = BreakOverlay { [weak self] in self?.endBreak() }
    private let activity = ActivityMonitor()
    private var timer: Timer?
    private var startupPeek: SlothPeek?
    /// Drawn over the countdown's colon while reminders are paused or it's outside working hours. It's a subview
    /// because AppKit places an `.imageOverlaps` button image without the status item's padding, so it lands left of
    /// the digits, and a wide image shifts the digits instead.
    private let stateSymbol = ClickThroughImageView()

    private let defaults = UserDefaults.standard
    private var deferBreaksDuringMeetings: Bool { defaults.bool(forKey: DefaultsKey.deferBreaksDuringMeetings) }
    /// Names by identifier, so Settings can list ignored apps that aren't running.
    private var ignoredApps: [String: String] {
        get { defaults.dictionary(forKey: DefaultsKey.ignoredMeetingApps)?.compactMapValues { $0 as? String } ?? [:] }
        set {
            defaults.set(newValue, forKey: DefaultsKey.ignoredMeetingApps)
            activity.ignoredMicrophoneApps = Set(newValue.keys)
            tick()
        }
    }
    /// Nil while reminders run at all hours.
    private var workingHours: WorkingHours? {
        guard defaults.bool(forKey: DefaultsKey.workingHoursOnly) else { return nil }
        return WorkingHours(start: ScheduleLimits.timeOfDay(defaults.integer(forKey: DefaultsKey.workingHoursStart)),
                            end: ScheduleLimits.timeOfDay(defaults.integer(forKey: DefaultsKey.workingHoursEnd)),
                            days: ScheduleLimits.workingDays(defaults.integer(forKey: DefaultsKey.workingDays)))
    }
    /// Each tick and the render after it read the clock once, so they agree on which side of a boundary they're on.
    /// A render that read it again just after the boundary could schedule the wake for the next one instead.
    private func withinWorkingHours(at date: Date) -> Bool {
        workingHours?.contains(date, in: calendar) ?? true
    }
    private let calendar = Calendar.autoupdatingCurrent
    private var clock: BreakTimer
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    override init() {
        defaults.register(defaults: [
            DefaultsKey.workSeconds: 20 * 60, DefaultsKey.breakSeconds: 20,
            DefaultsKey.longBreaksEnabled: true, DefaultsKey.longBreakSeconds: Int(BreakTimer.defaultLongBreakDuration),
            DefaultsKey.shortBreaksBeforeLongBreak: BreakTimer.defaultShortBreaksBeforeLongBreak,
            DefaultsKey.showBreakBanner: true, DefaultsKey.deferBreaksDuringMeetings: true,
            DefaultsKey.workingHoursStart: 9 * 60, DefaultsKey.workingHoursEnd: 17 * 60,
            DefaultsKey.workingDays: DaysOfWeek.mondayToFriday.rawValue,
        ])
        clock = BreakTimer(workDuration: defaults.duration(forKey: DefaultsKey.workSeconds),
                           breakDuration: defaults.duration(forKey: DefaultsKey.breakSeconds),
                           longBreakDuration: defaults.duration(forKey: DefaultsKey.longBreakSeconds),
                           shortBreaksBeforeLongBreak: defaults.shortBreaks,
                           longBreaksEnabled: defaults.bool(forKey: DefaultsKey.longBreaksEnabled),
                           now: ProcessInfo.processInfo.systemUptime)
        super.init()
        activity.ignoredMicrophoneApps = Set(ignoredApps.keys)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // bradipo shows no menu bar, but AppKit still looks up key equivalents in the main menu.
        NSApp.mainMenu = .keyEquivalents
        buildMenu()
        if let button = statusItem.button {
            button.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.title = clock.formattedRemainingTime
            stateSymbol.autoresizingMask = [.width, .height]
            stateSymbol.setAccessibilityElement(false)
            stateSymbol.isHidden = true
            button.addSubview(stateSymbol)
            if let peek = SlothPeek(button: button) {
                startupPeek = peek
                button.toolTip = "bradipo · Starting work interval"
                button.setAccessibilityLabel("bradipo, starting work interval, \(button.title)")
                let frames = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(animateStartup),
                                   userInfo: nil, repeats: true)
                timer = frames
                RunLoop.main.add(frames, forMode: .common)
                animateStartup()
                return
            }
        }
        startCountdown()
    }

    @objc private func animateStartup() {
        if startupPeek?.drawFrame(at: now) == false { startCountdown() }
    }

    private func startCountdown() {
        timer?.invalidate()
        startupPeek?.stop()
        startupPeek = nil
        // The tick follows a restart, so it can't start a break.
        let state = activity.sample(detectMeetings: deferBreaksDuringMeetings, fresh: false)
        let start = now
        let date = Date()
        clock.restart(at: start)
        clock.tick(at: start, activity: state, withinWorkingHours: withinWorkingHours(at: date))
        activity.onChange = { [weak self] in self?.tick() }
        // Working hours follow the wall clock, which can be set or change time zone while the Mac stays awake.
        // A new day can change when reminders are back from "tomorrow" to today.
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }
        render(at: date)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag, sender.windows.contains(where: { $0.isVisible && $0.canBecomeKey }) { return true }
        if let button = statusItem.button { openMenu(button) }
        return false
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false
        pauseStatus.isEnabled = false
        menu.addItem(pauseStatus)

        pause.target = self
        pause.action = #selector(togglePause)
        menu.addItem(pause)
        takeBreak.target = self
        menu.addItem(takeBreak)
        takeLongBreak.target = self
        takeLongBreak.subtitle = "Starts a new cycle"
        menu.addItem(takeLongBreak)
        menu.addItem(withTitle: "Restart Timer", action: #selector(restartTimer), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit bradipo", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "")
        quit.target = NSApp
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // Between break decisions the meeting check can reuse a recent result, which could leave a break action enabled
        // during a meeting that just started.
        update(fresh: true)
    }

    /// A click can't reach the menu bar behind the lock screen or a screen saver, so it clears a dropped unlock or `didstop`.
    /// A reopen can come from `open -a` while the person is away, so it only opens the menu.
    @objc private func statusItemClicked(_ button: NSStatusBarButton) {
        activity.notePersonPresent()
        openMenu(button)
    }

    private func openMenu(_ button: NSStatusBarButton) {
        if startupPeek != nil { startCountdown() }
        guard !isOpeningOrTrackingMenu, let window = button.window else { return }
        let frame = button.convert(button.bounds, to: nil)
        let leadingX = NSApp.userInterfaceLayoutDirection == .rightToLeft ? frame.maxX : frame.minX
        var anchor = window.convertPoint(toScreen: NSPoint(x: leadingX, y: 0))
        if let event = NSApp.currentEvent, event.window === window,
           event.type == .leftMouseDown || event.type == .rightMouseDown {
            let pointer = NSEvent.mouseLocation
            // The first click on another display can arrive before AppKit moves the
            // status-item window. Use the click offset and that display's menu bar.
            if !window.frame.contains(pointer),
               let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) {
                anchor.x = pointer.x + leadingX - event.locationInWindow.x
                anchor.y = min(screen.visibleFrame.maxY, screen.frame.maxY - window.frame.height)
            }
        }
        // popUp positions the menu content. Leave room for its rounded border.
        anchor.y -= 6
        // Return the click or reopen event to macOS before entering menu tracking.
        isOpeningOrTrackingMenu = true
        perform(#selector(trackMenu(at:)), with: NSValue(point: anchor), afterDelay: 0, inModes: [.default])
    }

    @objc private func trackMenu(at position: NSValue) {
        defer { isOpeningOrTrackingMenu = false }
        guard let button = statusItem.button else { return }
        button.highlight(true)
        defer { button.highlight(false) }
        menu.popUp(positioning: nil, at: position.pointValue, in: nil)
    }

    @objc private func tick() {
        update(fresh: false)
    }

    /// Ticks with a fresh meeting check if `fresh` is set or the tick could start a break.
    private func update(fresh: Bool) {
        // Use one timestamp, so the tick that starts a break is the one whose sample was fresh.
        let time = now
        let date = Date()
        let within = withinWorkingHours(at: date)
        let isBreakDue = clock.isBreakDue(at: time, withinWorkingHours: within)
        let state = activity.sample(detectMeetings: deferBreaksDuringMeetings, fresh: fresh || isBreakDue)
        let transition = clock.tick(at: time, activity: state, withinWorkingHours: within)
        render(at: date)
        if let sound = breakSounds.first(where: { $0.transition == transition })?.sound, defaults.bool(forKey: sound.isOnKey) {
            BreakSound.play(sound.fileName(saved: defaults.string(forKey: sound.fileNameKey)))
        }
    }

    /// `date` is the moment the tick before it read the clock.
    private func render(at date: Date) {
        let time = clock.formattedRemainingTime
        let resting = clock.phase == .resting
        let reason: String? = switch clock.pauseReason {
        case .manual: "Reminders paused"
        case .outsideWorkingHours: outsideWorkingHoursDescription(at: date)
        case .meeting: "\(clock.breakKind.title) due · \(meetingDescription)"
        case .unavailable: "Paused · Mac is away"
        case nil: nil
        }
        let paused = clock.isManuallyPaused
        let symbol: (name: String, size: CGFloat)? = switch clock.pauseReason {
        case .manual: ("pause.fill", NSFont.systemFontSize)
        // At the text's size the moon would be wider than the pause symbol and cover the digits beside the colon.
        case .outsideWorkingHours: ("moon.fill", 9)
        case .meeting, .unavailable, nil: nil
        }
        if let button = statusItem.button {
            button.title = time
            if symbol != nil {
                // The colon would show through the symbol, such as between the pause symbol's bars.
                let title = button.attributedTitle.withForegroundColor(.tertiaryLabelColor)
                title.addAttribute(.foregroundColor, value: NSColor.clear, range: (time as NSString).range(of: ":"))
                button.attributedTitle = title
            }
            stateSymbol.symbolConfiguration = symbol.map { .init(pointSize: $0.size, weight: .bold) }
            stateSymbol.image = symbol.flatMap { NSImage(systemSymbolName: $0.name, accessibilityDescription: nil) }
            stateSymbol.isHidden = symbol == nil
            // The title is monospaced, so in m:ss the colon sits half a character left of center.
            let halfCharacter = button.attributedTitle.size().width / CGFloat(time.count) / 2
            stateSymbol.frame = button.bounds.offsetBy(dx: time.count == 4 ? -halfCharacter : 0, dy: 0)
            let description = reason ?? (resting ? clock.breakKind.title : "Work interval")
            button.toolTip = "bradipo · \(description)"
            button.setAccessibilityLabel("bradipo, \(description), \(time)")
        }
        pauseStatus.isHidden = reason == nil || paused
        pauseStatus.title = reason ?? ""
        takeBreak.title = resting ? "Stop \(clock.breakKind.title.lowercased())" : "Take a \(clock.breakKind.title.capitalized)"
        takeBreak.subtitle = breakActionSubtitle
        takeBreak.action = resting ? #selector(endBreak) : #selector(startBreak)
        takeBreak.isEnabled = resting || clock.canStartBreak
        // While a long break is next, the break action already offers it.
        takeLongBreak.isHidden = resting || !clock.longBreaksEnabled || clock.breakKind == .long
        takeLongBreak.isEnabled = clock.canStartBreak
        pause.isEnabled = !resting
        pause.title = paused ? "Resume Reminders" : "Pause Reminders"
        if resting {
            overlay.show(timer: clock)
        } else {
            overlay.hide()
        }

        timer?.invalidate()
        // Outside working hours nothing else ticks, and a countdown that's held within them resets as they end.
        guard let delay = clock.timeUntilNextTick
                ?? workingHours?.nextBoundary(after: date, in: calendar)?.timeIntervalSinceNow else {
            timer = nil
            return
        }
        let next = Timer(timeInterval: delay, target: self, selector: #selector(tick), userInfo: nil, repeats: false)
        // Give macOS room to coalesce wake-ups. Apple suggests a tolerance of at least 10% of a repeating timer's interval,
        // and these ticks recur at most 1 s apart. Ticks often fire the full 0.1 s late: the countdown reschedules from the
        // remaining time, so its lag doesn't build up, but pauses recheck up to 0.1 s further apart.
        next.tolerance = 0.1
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private var meetingDescription: String {
        switch activity.meetingCause {
        case .camera: "Camera in use"
        case .microphone(let app?): "\(app.name) is using the mic"
        case .microphone(nil), nil: "Mic in use"
        }
    }

    /// Says when reminders are back: "at 9:00" for today, "tomorrow at 9:00", or "Monday at 9:00" later on.
    private func outsideWorkingHoursDescription(at date: Date) -> String {
        guard let start = workingHours?.nextBoundary(after: date, in: calendar) else { return "Outside working hours" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: start))
        let day = switch days.day {
        case 0: ""
        case 1: "tomorrow "
        default: "\(start.formatted(.dateTime.weekday(.wide))) "
        }
        return "Outside working hours · Back \(day)at \(start.formatted(date: .omitted, time: .shortened))"
    }

    private var breakActionSubtitle: String? {
        guard clock.longBreaksEnabled else { return nil }
        let remaining = clock.shortBreaksRemaining
        if clock.phase == .resting && clock.breakKind == .long {
            return "Next cycle · \(shortBreakCountLabel(remaining))"
        }
        if remaining == 0 {
            let total = clock.shortBreaksBeforeLongBreak
            return total == 1 ? "Short break taken" : "All \(shortBreakCountLabel(total)) taken"
        }
        return "\(shortBreakCountLabel(remaining)) until the long break"
    }

    private func shortBreakCountLabel(_ count: Int) -> String {
        "\(count) short \(count == 1 ? "break" : "breaks")"
    }

    @objc private func startBreak(_ sender: NSMenuItem) {
        let time = now
        let date = Date()
        clock.tick(at: time, activity: activity.sample(detectMeetings: deferBreaksDuringMeetings, fresh: true),
                   withinWorkingHours: withinWorkingHours(at: date))
        if sender === takeLongBreak {
            clock.startLongBreak(at: time)
        } else {
            clock.startBreak(at: time)
        }
        render(at: date)
    }

    @objc private func restartTimer() {
        clock.restart(at: now)
        tick()
    }

    @objc private func endBreak() {
        clock.endBreak(at: now)
        tick()
    }

    @objc private func showSettings() {
        // The status menu restores focus to the previous app as it closes.
        menu.cancelTrackingWithoutAnimation()
        perform(#selector(presentSettings), with: nil, afterDelay: 0, inModes: [.default])
    }

    @objc private func presentSettings() {
        settings.presentFromMenuBar()
    }

    @objc private func togglePause() {
        clock.setManuallyPaused(!clock.isManuallyPaused, at: now)
        tick()
    }

    /// Settings saves a change before asking for it to be applied.
    private func applySettings() {
        overlay.applySettings()
        clock.configure(workDuration: defaults.duration(forKey: DefaultsKey.workSeconds),
                        breakDuration: defaults.duration(forKey: DefaultsKey.breakSeconds),
                        longBreakDuration: defaults.duration(forKey: DefaultsKey.longBreakSeconds),
                        shortBreaksBeforeLongBreak: defaults.shortBreaks,
                        longBreaksEnabled: defaults.bool(forKey: DefaultsKey.longBreaksEnabled), at: now)
        tick()
    }
}

private extension UserDefaults {
    func duration(forKey key: String) -> TimeInterval {
        TimeInterval(ScheduleLimits.seconds(integer(forKey: key)))
    }

    var shortBreaks: Int {
        ScheduleLimits.shortBreaks(integer(forKey: DefaultsKey.shortBreaksBeforeLongBreak))
    }
}

extension BreakKind {
    var title: String { self == .short ? "Short break" : "Long break" }
}

extension NSAttributedString {
    func withForegroundColor(_ color: NSColor) -> NSMutableAttributedString {
        let text = NSMutableAttributedString(attributedString: self)
        text.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: text.length))
        return text
    }
}

/// Shows an image over another view without taking its clicks.
private final class ClickThroughImageView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private extension NSMenu {
    /// The shortcuts a window with text fields needs: closing it and editing text.
    static var keyEquivalents: NSMenu {
        let items = NSMenu()
        for (title, action, key) in [
            ("Close", #selector(NSWindow.performClose(_:)), "w"),
            ("Undo", Selector(("undo:")), "z"),
            ("Redo", Selector(("redo:")), "Z"),
            ("Cut", #selector(NSText.cut(_:)), "x"),
            ("Copy", #selector(NSText.copy(_:)), "c"),
            ("Paste", #selector(NSText.paste(_:)), "v"),
            ("Select All", #selector(NSText.selectAll(_:)), "a"),
        ] {
            items.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = items
        return menu
    }
}

extension NSWindow {
    /// Call after the status menu returns focus, on a window that doesn't hide on
    /// deactivation: the menu-bar app can still be inactive after it requests
    /// activation, so the window is ordered front anyway.
    @MainActor func presentFromMenuBar() {
        makeKeyAndOrderFront(nil)
        NSApp.activate()
        orderFrontRegardless()
    }
}
