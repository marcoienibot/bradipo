import AppKit
import BradipoCore
import ColorSync
import Observation
import SwiftUI

@MainActor
final class BreakOverlay: NSObject {
    private var glows: [ReminderPanel] = []
    private var banners: [ReminderPanel] = []
    private var isPreviewingGlow = false
    private var showsBanner: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.showBreakBanner) }
    /// Off until turned on, so people watching a screen share or recording don't see the glow or the banner.
    private var sharingType: NSWindow.SharingType {
        UserDefaults.standard.bool(forKey: DefaultsKey.showBreaksInScreenSharing) ? .readOnly : .none
    }
    let intensity = BorderGlowIntensity()
    private var countdown: BreakCountdown?
    private let onEndBreak: () -> Void

    init(onEndBreak: @escaping () -> Void) {
        self.onEndBreak = onEndBreak
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show(timer: BreakTimer) {
        if let countdown {
            countdown.timer = timer
            // Another app can change the cursor without moving the pointer.
            refreshBannerCursor()
            return
        }
        countdown = BreakCountdown(timer: timer)
        updatePanels(animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    }

    func hide() {
        guard countdown != nil else { return }
        countdown = nil
        updatePanels()
    }

    func setGlowPreview(_ visible: Bool) {
        isPreviewingGlow = visible
        updatePanels()
    }

    /// Applies the saved banner and screen-sharing settings to a break or preview that's on screen.
    func applySettings() {
        updatePanels()
        for panel in glows + banners { panel.sharingType = sharingType }
    }

    func setGlowIntensity(_ value: Double) {
        guard value != intensity.value else { return }
        let wasOff = intensity.value == 0
        intensity.value = value
        if wasOff || value == 0 { updatePanels() }
        // The slider tracks the mouse in a nested run loop. Flush the other
        // windows' SwiftUI layout and layer updates before the next drag event.
        for panel in glows {
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.displayIfNeeded()
        }
        CATransaction.flush()
    }

    func canResetBanners(timer: BreakTimer) -> Bool {
        let frames = NSScreen.screens.reduce(into: [String: CGRect]()) { $0[$1.bannerDisplayID] = $1.visibleFrame }
        return BreakCardPlacement.canReset(visibleFrames: frames) {
            makeCard(countdown: countdown ?? BreakCountdown(timer: timer)).fittingSize
        }
    }

    func resetBanners() {
        BreakCardPlacement.resetAll()
        NotificationCenter.default.post(name: .bannerPlacementChanged, object: nil)
        for panel in banners {
            if let card = panel.contentView as? CardHostingView, let placement = card.placement {
                panel.setFrame(placement.savedFrame, display: true)
                card.scheduleCursorUpdate()
            }
        }
    }

    @objc private func displaysChanged() {
        dismiss(&glows)
        dismiss(&banners)
        updatePanels()
    }

    private func dismiss(_ panels: inout [ReminderPanel]) {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
    }

    private func updatePanels(animated: Bool = false) {
        var added: [ReminderPanel] = []
        if intensity.value == 0 || (countdown == nil && !isPreviewingGlow) {
            dismiss(&glows)
        } else if glows.isEmpty {
            glows = NSScreen.screens.map { screen in
                ReminderPanel(content: NSHostingView(rootView: ScreenGlow(intensity: intensity)),
                              frame: screen.frame, receivesClicks: false)
            }
            added += glows
        }

        if showsBanner, let countdown {
            if banners.isEmpty {
                banners = NSScreen.screens.map { makeBanner(on: $0, countdown: countdown) }
                added += banners
            }
        } else {
            dismiss(&banners)
        }
        guard !added.isEmpty else { return }
        // AppKit lists visible windows front to back on the active Space.
        // Insert each new glow immediately below the backmost break card.
        let anchor = NSWindow.windowNumbers()?.last { number in
            banners.contains { $0.windowNumber == number.intValue }
        }
        for panel in added {
            panel.sharingType = sharingType
            panel.alphaValue = animated ? 0 : 1
            if let anchor, glows.contains(panel) {
                panel.order(.below, relativeTo: anchor.intValue)
            } else {
                panel.orderFrontRegardless()
            }
        }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.55
                added.forEach { $0.animator().alphaValue = 1 }
            } completionHandler: { [weak self] in
                Task { @MainActor in self?.refreshBannerCursor() }
            }
        } else {
            refreshBannerCursor()
        }
    }

    private func makeCard(countdown: BreakCountdown) -> CardHostingView {
        CardHostingView(rootView: BreakCard(countdown: countdown, onEndBreak: onEndBreak))
    }

    private func makeBanner(on screen: NSScreen, countdown: BreakCountdown) -> ReminderPanel {
        let card = makeCard(countdown: countdown)
        let size = card.fittingSize
        let placement = BreakCardPlacement(displayID: screen.bannerDisplayID, visibleFrame: screen.visibleFrame, cardSize: size)
        card.placement = placement
        card.sizingOptions = []
        card.rootView.naturalSize = size
        return ReminderPanel(content: card, frame: placement.savedFrame, receivesClicks: true)
    }

    private func refreshBannerCursor() {
        for panel in banners { (panel.contentView as? CardHostingView)?.scheduleCursorUpdate() }
    }
}

extension Notification.Name {
    /// Posted after a banner's saved size or position changes: when a drag ends or is cut short, and after a reset.
    static let bannerPlacementChanged = Notification.Name("bannerPlacementChanged")
}

private extension NSScreen {
    var bannerDisplayID: String {
        cgDirectDisplayID.flatMap { CGDisplayCreateUUIDFromDisplayID($0) }
            .map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? localizedName
    }
}

private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func orderOut(_ sender: Any?) {
        let card = contentView as? CardHostingView
        card?.endDrag()
        card?.releaseCursor()
        super.orderOut(sender)
    }

    init(content: NSView, frame: NSRect, receivesClicks: Bool) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = receivesClicks
        hidesOnDeactivate = false
        ignoresMouseEvents = !receivesClicks
        acceptsMouseMovedEvents = receivesClicks
        if receivesClicks {
            setAccessibilityLabel("Break reminder")
        } else {
            setAccessibilityElement(false)
        }
        animationBehavior = .none
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary,
            .stationary, .ignoresCycle,
        ]
        contentView = content
        setFrame(frame, display: true)
    }
}

private final class CardHostingView: NSHostingView<BreakCard> {
    private typealias ResizeHandle = BreakCardPlacement.ResizeHandle
    private struct Grab {
        let pointer: NSPoint
        let frame: NSRect
        let handle: ResizeHandle?
    }

    var placement: BreakCardPlacement?
    private var grab: Grab?
    private var isDragging = false
    private var refreshPending = false
    private static weak var cursorOwner: CardHostingView?
    private lazy var hoverArea = NSTrackingArea(
        rect: .zero, options: [.inVisibleRect, .activeAlways, .mouseEnteredAndExited, .mouseMoved],
        owner: self, userInfo: nil
    )

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Route every click on the banner, label and resize border alike, to this view.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    private func resizeHandle(at point: NSPoint) -> ResizeHandle? {
        guard bounds.contains(point) else { return nil }
        let left = point.x - bounds.minX
        let right = bounds.maxX - point.x
        let top = isFlipped ? point.y - bounds.minY : bounds.maxY - point.y
        let bottom = bounds.height - top

        // Leave a straight section of each edge available even on the smallest banner.
        // The corner zones and the 8 pt edge bands cover BreakCard's 29 pt rounded corners, so every
        // point in bounds is either the card or a resize handle. The open-hand cursor and the click
        // that ends a break in mouseUp rely on that.
        let cornerReach = min(20, bounds.width / 3, bounds.height / 3)
        if min(left, right) < cornerReach, min(top, bottom) < cornerReach {
            if left < right { return top < bottom ? .topLeft : .bottomLeft }
            return top < bottom ? .topRight : .bottomRight
        }
        let border: CGFloat = 8
        if min(left, right) < border { return left < right ? .left : .right }
        if min(top, bottom) < border { return top < bottom ? .top : .bottom }
        return nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // The break panel never becomes key, even when the pointer is over it.
        if !trackingAreas.contains(hoverArea) { addTrackingArea(hoverArea) }
    }

    private func resizeCursor(for handle: ResizeHandle) -> NSCursor {
        let position: NSCursor.FrameResizePosition = switch handle {
        case .left: .left
        case .right: .right
        case .top: .top
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .bottomRight: .bottomRight
        case .topLeft: .topLeft
        case .topRight: .topRight
        }
        return .frameResize(position: position, directions: .all)
    }

    // AppKit normally leaves the visible cursor to the foreground app. Resolve
    // this optional WindowServer property at runtime so dragging still works
    // if a future macOS version removes it.
    private static let allowBackgroundCursor: ((Bool) -> Void)? = {
        typealias ConnectionID = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        guard let quartz = CFBundleGetBundleWithIdentifier("com.apple.CoreGraphics" as CFString),
              let idSymbol = CFBundleGetFunctionPointerForName(quartz, "CGSMainConnectionID" as CFString),
              let setSymbol = CFBundleGetFunctionPointerForName(quartz, "CGSSetConnectionProperty" as CFString)
        else { return nil }

        let connection = unsafeBitCast(idSymbol, to: ConnectionID.self)()
        let setProperty = unsafeBitCast(setSymbol, to: SetProperty.self)
        return { enabled in
            _ = setProperty(connection, connection, "SetsCursorInBackground" as CFString,
                            enabled ? kCFBooleanTrue : kCFBooleanFalse)
        }
    }()

    func releaseCursor() {
        guard Self.cursorOwner === self else { return }
        Self.allowBackgroundCursor?(false)
        Self.cursorOwner = nil
    }

    func scheduleCursorUpdate() {
        guard !refreshPending else { return }
        refreshPending = true
        // The foreground app can reset the cursor as WindowServer delivers
        // pointer or geometry changes. Reapply it after that event settles.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) { [weak self] in
            self?.refreshCursor()
        }
    }

    private func refreshCursor() {
        refreshPending = false
        let pointer = NSEvent.mouseLocation
        guard let window, window.isVisible, window.frame.contains(pointer),
              NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0) == window.windowNumber
        else {
            releaseCursor()
            return
        }

        if Self.cursorOwner !== self {
            Self.allowBackgroundCursor?(true)
            Self.cursorOwner = self
        }
        let local = convert(window.convertPoint(fromScreen: pointer), from: nil)
        if let grab, isDragging {
            (grab.handle.map(resizeCursor) ?? .closedHand).set()
        } else if let handle = resizeHandle(at: local) {
            resizeCursor(for: handle).set()
        } else {
            NSCursor.openHand.set()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        scheduleCursorUpdate()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        scheduleCursorUpdate()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === hoverArea { releaseCursor() }
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let point = event.locationInWindow
        grab = Grab(pointer: window.convertPoint(toScreen: point), frame: window.frame,
                    handle: resizeHandle(at: convert(point, from: nil)))
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        updateDrag(at: event.locationInWindow)
    }

    private func updateDrag(at point: NSPoint) {
        guard let window, window.isVisible, let grab, let placement else { return }
        let pointer = window.convertPoint(toScreen: point)
        let delta = CGVector(dx: pointer.x - grab.pointer.x, dy: pointer.y - grab.pointer.y)
        guard isDragging || hypot(delta.dx, delta.dy) >= 4 else { return }
        isDragging = true
        if let handle = grab.handle {
            window.setFrame(placement.resize(grab.frame, from: handle, by: delta), display: true)
        } else {
            window.setFrameOrigin(placement.move(to: grab.frame.offsetBy(dx: delta.dx, dy: delta.dy).origin))
        }
        scheduleCursorUpdate()
    }

    /// Also for a break that ends while its banner is held. No mouse-up follows then, and the drag has
    /// already saved the banner's new place.
    func endDrag() {
        guard grab != nil else { return }
        grab = nil
        if isDragging { NotificationCenter.default.post(name: .bannerPlacementChanged, object: nil) }
    }

    override func mouseUp(with event: NSEvent) {
        guard let grab else { return }
        updateDrag(at: event.locationInWindow)
        endDrag()
        if !isDragging, grab.handle == nil, window?.isVisible == true, bounds.contains(convert(event.locationInWindow, from: nil)) {
            rootView.onEndBreak()
        } else {
            scheduleCursorUpdate()
        }
    }
}

@Observable @MainActor
private final class BreakCountdown {
    var timer: BreakTimer
    init(timer: BreakTimer) { self.timer = timer }
}

private struct ScreenGlow: View {
    @AppStorage(BreakAccent.defaultsKey) private var accent = BreakAccent.green
    let intensity: BorderGlowIntensity

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(accent.glow.opacity(intensity.opacity), lineWidth: intensity.lineWidth)
            .blur(radius: intensity.blurRadius)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct BreakCard: View {
    let countdown: BreakCountdown
    let onEndBreak: () -> Void
    var naturalSize: CGSize?

    private static let sloth = NSImage(named: "Sloth.png")
    @AppStorage(BreakAccent.defaultsKey) private var accent = BreakAccent.green
    private let cream = Color(red: 0.97, green: 0.96, blue: 0.89)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 29)
        Group {
            if let naturalSize {
                GeometryReader { area in
                    label.scaleEffect(min(area.size.width / naturalSize.width, area.size.height / naturalSize.height))
                        .frame(width: area.size.width, height: area.size.height)
                }
            } else {
                label
            }
        }
        .background(accent.background, in: shape)
        .overlay { shape.strokeBorder(cream.opacity(0.24), lineWidth: 1) }
        // Give the window server a hit target even at the transparent-looking corners.
        .background(Color.black.opacity(0.01))
        .contentShape(Rectangle())
        .help("Drag an edge or corner to resize. Drag the center to move, or click it to end this break.")
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onEndBreak() }
        .accessibilityLabel("End \(countdown.timer.breakKind.title.lowercased())")
        .accessibilityValue("\(countdown.timer.remainingSeconds) seconds remaining")
    }

    private var label: some View {
        HStack(spacing: 12) {
            if let sloth = Self.sloth {
                Image(nsImage: sloth)
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .frame(width: 42, height: 42)
                    .background(cream, in: Circle())
            }
            Text(verbatim: countdown.timer.breakKind.title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(cream)
            Rectangle()
                .fill(accent.divider.opacity(0.40))
                .frame(width: 1, height: 18)
            Text(verbatim: countdown.timer.formattedBreakTime)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(accent.countdown)
        }
        .padding(.leading, Self.sloth == nil ? 20 : 8)
        .padding(.trailing, 20)
        .frame(height: 58)
        .fixedSize()
    }
}
