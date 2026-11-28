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
        center()
        // bradipo shows no menu bar, but AppKit still looks up key equivalents in the main menu.
        if NSApp.mainMenu == nil { NSApp.mainMenu = .keyEquivalents }
    }
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
