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
}

private extension NSView {
    func firstSubview<View: NSView>(of type: View.Type) -> View? {
        subviews.lazy.compactMap { ($0 as? View) ?? $0.firstSubview(of: type) }.first
    }
}
