import AppKit
import Observation
import ServiceManagement

@MainActor @Observable
final class LoginItem {
    private(set) var status: SMAppService.Status
    private let service = SMAppService.mainApp

    init() {
        status = service.status
    }

    /// The person can approve or remove the login item in System Settings while bradipo runs.
    func refresh() {
        status = service.status
    }

    func toggle() {
        // The status shown can be older than a change made in System Settings.
        refresh()
        defer { refresh() }
        do {
            if status == .enabled {
                try service.unregister()
                return
            }
            if status != .requiresApproval {
                try service.register()
            }
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Open Login Items…")
            NSApp.activate()
            if alert.runModal() == .alertSecondButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
