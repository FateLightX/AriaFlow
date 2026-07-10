import Foundation
import ServiceManagement

enum LoginItemService {
    private static let legacyLabel = "com.ariaflow.desktop.login"

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func removeLegacyLaunchAgent() {
        let domain = "gui/\(getuid())"
        let target = "\(domain)/\(legacyLabel)"
        try? runLaunchctl(["bootout", target])
        try? FileManager.default.removeItem(at: legacyLaunchAgentURL)
    }

    private static func runLaunchctl(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
    }

    private static var legacyLaunchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents", directoryHint: .isDirectory)
            .appending(path: "\(legacyLabel).plist")
    }
}
