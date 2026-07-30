import Foundation
import ServiceManagement

enum LoginItemStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable

    var isRequestedEnabled: Bool {
        self == .enabled || self == .requiresApproval
    }

    var detailText: String {
        switch self {
        case .notRegistered:
            "关闭"
        case .enabled:
            "已添加到系统登录项"
        case .requiresApproval:
            "需要在系统设置中允许"
        case .unavailable:
            "当前应用无法注册登录项"
        }
    }
}

enum LoginItemService {
    private static let legacyLabel = "com.ariaflow.desktop.login"

    static var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled, service.status != .requiresApproval else { return }
            try service.register()
        } else {
            guard service.status != .notRegistered, service.status != .notFound else { return }
            try service.unregister()
        }
    }

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
