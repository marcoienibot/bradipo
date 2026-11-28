import AppKit
import SwiftUI

/// What the settings window needs from the running app, which owns the timer and the break overlay.
@MainActor
struct SettingsHost {
    let overlay: BreakOverlay
    let login: LoginItem
    let updater: Updater
    /// The apps whose microphone use doesn't hold breaks, as names by identifier.
    let ignoredApps: Binding<[String: String]>
    /// Call after saving a change, so the timer and a break on screen pick it up.
    let apply: () -> Void
    let canResetBanners: () -> Bool
}

@MainActor
final class SettingsWindow: NSWindow {
    init(host: SettingsHost) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                   backing: .buffered, defer: true)
        isReleasedWhenClosed = false
        collectionBehavior.insert(.moveToActiveSpace)
        let content = NSHostingController(rootView: SettingsView(host: host))
        // Lets the split view put the section's title and the sidebar into the title bar, as in a SwiftUI scene.
        content.sceneBridgingOptions = [.title, .toolbars]
        contentViewController = content
        // The hosting controller sizes the window later, which would leave it centered by its corner.
        setContentSize(content.view.fittingSize)
        center()
    }

    /// Typing right after Settings opens searches, as in System Settings.
    override func makeKeyAndOrderFront(_ sender: Any?) {
        if !isVisible, let search = contentView?.firstSubview(of: NSSearchField.self) { makeFirstResponder(search) }
        super.makeKeyAndOrderFront(sender)
    }

    /// A field still being edited saves what it shows, as when the keyboard leaves it. Otherwise the edit
    /// would stay open in the hidden window and be saved only when Settings opens again.
    override func close() {
        makeFirstResponder(nil)
        super.close()
    }

    /// A click outside the text fields takes the keyboard from a setting's field, so the field saves what it shows.
    /// A row's title, the space around the rows and SwiftUI's pop-ups don't take the keyboard, so the field would
    /// keep editing. The search field keeps the keyboard, so typing and Esc still work on the search.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, let editor = firstResponder as? NSText, !(editor.delegate is NSSearchField),
           let view = contentView?.superview?.hitTest(event.locationInWindow), !view.takesTyping {
            makeFirstResponder(nil)
        }
        super.sendEvent(event)
    }
}

private extension NSView {
    func firstSubview<View: NSView>(of type: View.Type) -> View? {
        subviews.lazy.compactMap { ($0 as? View) ?? $0.firstSubview(of: type) }.first
    }

    /// Whether this is part of a text field that a click puts the keyboard in, or of the text view editing one.
    var takesTyping: Bool {
        sequence(first: self, next: \.superview).contains {
            $0 is NSText || ($0 as? NSTextField)?.acceptsFirstResponder == true
        }
    }
}
