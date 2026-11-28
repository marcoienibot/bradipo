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

    func setEnabled(_ enabled: Bool) {
        // The switch can show a status older than a change made in System Settings.
        // Then the login item may already be as asked, and flipping it would do the opposite.
        refresh()
        guard enabled != (status == .enabled) else { return }
        defer { refresh() }
        do {
            guard enabled else {
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
