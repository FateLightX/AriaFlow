import SwiftUI

enum ConnectionState: String, CaseIterable, Identifiable {
    case starting
    case connected
    case failed
    case stopped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starting: "正在连接"
        case .connected: "已连接"
        case .failed: "连接失败"
        case .stopped: "已停止"
        }
    }

    var detail: String {
        switch self {
        case .starting: "正在启动 aria2-next 引擎"
        case .connected: "aria2-next RPC 已连接"
        case .failed: "无法连接 aria2-next RPC"
        case .stopped: "下载引擎已停止"
        }
    }

    var color: Color {
        switch self {
        case .starting: .orange
        case .connected: .green
        case .failed: .red
        case .stopped: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .starting: "hourglass"
        case .connected: "checkmark.circle.fill"
        case .failed: "wifi.slash"
        case .stopped: "stop.circle"
        }
    }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case waiting
    case complete
    case failed
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .active: "下载中"
        case .waiting: "等待中"
        case .complete: "已完成"
        case .failed: "已失败"
        case .history: "历史"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .active: "arrow.down.circle"
        case .waiting: "clock"
        case .complete: "checkmark.circle"
        case .failed: "xmark.circle"
        case .history: "clock.arrow.circlepath"
        }
    }
}

enum TaskStatus: String {
    case active
    case waiting
    case paused
    case complete
    case failed

    var title: String {
        switch self {
        case .active: "下载中"
        case .waiting: "等待中"
        case .paused: "已暂停"
        case .complete: "已完成"
        case .failed: "已失败"
        }
    }

    var color: Color {
        switch self {
        case .active: .blue
        case .waiting, .paused: .orange
        case .complete: .green
        case .failed: .red
        }
    }

    var canPause: Bool {
        self == .active || self == .waiting
    }

    var canResume: Bool {
        self == .paused || self == .waiting
    }
}

enum TaskSort: String, CaseIterable, Identifiable {
    case status
    case name
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status: "状态"
        case .name: "名称"
        case .progress: "进度"
        }
    }
}

struct DownloadTask: Identifiable, Hashable {
    var name: String
    var protocolLabel: String
    var status: TaskStatus
    var progress: Double
    var completedSize: String
    var totalSize: String
    var downloadSpeed: String
    var uploadSpeed: String
    var remainingTime: String
    var savePath: String
    var gid: String
    var detail: String
    var errorMessage: String?
    var fileNames: [String]
    var localFilePaths: [String]
    var sourceURLs: [String]
    var infoHash: String?
    var ed2kHash: String?

    var id: String { gid }

    var sourceLink: String? {
        if let sourceURL = sourceURLs.first {
            return sourceURL
        }
        if let infoHash, !infoHash.isEmpty {
            return "magnet:?xt=urn:btih:\(infoHash)"
        }
        return nil
    }
}

struct HistoryItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var gid: String?
    var name: String
    var result: String
    var finishedAt: String
    var location: String
}

struct FileCandidate: Identifiable {
    let id = UUID()
    var aria2Index = ""
    var name: String
    var size: String
    var isSelected: Bool
}
