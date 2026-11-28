import Foundation

/// A program recording from the microphone, named the way the person knows it:
/// Discord rather than the Discord Helper process that does the recording.
public struct RecordingApp: Hashable, Sendable {
    /// A bundle identifier, or a path for a program without one. Ignoring an app saves it with the name.
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// Names the program behind an audio process.
    ///
    /// Inside an app bundle, the outermost app names it, so every helper of an app shares the app's identity.
    /// Otherwise, as for a daemon or an XPC service, the process's own bundle ID identifies it,
    /// or its executable path when it has none.
    /// - Parameters:
    ///   - executablePath: Nil when the path can't be read, for example because the process ended.
    ///   - bundleID: The bundle ID Core Audio reports for the process, which is empty for a program without one.
    ///   - lookUpApp: Reads the bundle identifier and display name of the app bundle at a path.
    public init?(executablePath: String?, bundleID: String?,
                 lookUpApp: (String) -> (identifier: String?, name: String)) {
        if let executablePath, let appPath = Self.appBundlePath(containing: executablePath) {
            let app = lookUpApp(appPath)
            // Foundation reports an empty identifier for some bundles without one, which would merge them all.
            let identifier = app.identifier.flatMap { $0.isEmpty ? nil : $0 }
            self.init(id: identifier ?? appPath, name: app.name)
            return
        }
        let executableName = executablePath.flatMap { $0.split(separator: "/").last.map(String.init) }
        if let bundleID, !bundleID.isEmpty {
            self.init(id: bundleID, name: executableName ?? bundleID)
        } else if let executablePath, let executableName {
            self.init(id: executablePath, name: executableName)
        } else {
            return nil
        }
    }

    /// The outermost app bundle on an executable's path, or nil if the executable isn't inside one.
    public static func appBundlePath(containing executablePath: String) -> String? {
        // The last component is the executable itself, which the bundle has to contain.
        let directories = executablePath.split(separator: "/", omittingEmptySubsequences: false).dropLast()
        // macOS treats the extension as case-insensitive.
        guard let app = directories.firstIndex(where: { $0.lowercased().hasSuffix(".app") }) else { return nil }
        return directories[...app].joined(separator: "/")
    }
}

/// The two lists for choosing which apps' microphone use doesn't count as a meeting.
public struct IgnoredAppsSections: Equatable, Sendable {
    /// Apps using the microphone that aren't ignored, each listed once.
    public let recording: [RecordingApp]
    /// Every ignored app, whether it's running or not.
    public let ignored: [RecordingApp]

    public init(recording: [RecordingApp], ignored: [RecordingApp]) {
        let ignoredIDs = Set(ignored.map(\.id))
        var listed = Set<String>()
        // An app can record through several helper processes.
        self.recording = Self.sorted(recording.filter { !ignoredIDs.contains($0.id) && listed.insert($0.id).inserted })
        self.ignored = Self.sorted(ignored)
    }

    private static func sorted(_ apps: [RecordingApp]) -> [RecordingApp] {
        apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
