import Foundation
import SwiftData

// MARK: - SwiftData 本地資料模型

@Model
final class MeetingRecord {
    @Attribute(.unique) var id: UUID
    var title: String?
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int?
    /// "processing" | "complete" | "failed"
    var statusRaw: String
    var transcript: String?
    /// 10 個重點，JSON 編碼的 [String]
    var summaryPointsData: Data?
    /// Next Steps，JSON 編碼的 [NextStepItem]
    var nextStepsData: Data?
    var errorMessage: String?
    var audioFilePath: String?   // 音檔路徑，永久保留供重播與重試用
    var isPinned: Bool?          // optional 確保 SwiftData lightweight migration 成功
    /// 說話者名稱對應表，JSON 編碼的 [String: String]，e.g. ["A": "老闆", "B": "我"]
    var speakerNamesData: Data?
    /// 討論議題摘要，JSON 編碼的 [DiscussionTopic]
    var topicsData: Data?
    var createdAt: Date

    init(title: String? = nil, startedAt: Date = .now) {
        self.id = UUID()
        self.title = title
        self.startedAt = startedAt
        self.statusRaw = "processing"
        self.isPinned = nil
        self.createdAt = .now
    }

    // MARK: - Computed helpers

    var status: MeetingStatus {
        get { MeetingStatus(rawValue: statusRaw) ?? .processing }
        set { statusRaw = newValue.rawValue }
    }

    var summaryPoints: [String] {
        get {
            guard let data = summaryPointsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            summaryPointsData = try? JSONEncoder().encode(newValue)
        }
    }

    var nextSteps: [NextStepItem] {
        get {
            guard let data = nextStepsData else { return [] }
            return (try? JSONDecoder().decode([NextStepItem].self, from: data)) ?? []
        }
        set {
            nextStepsData = try? JSONEncoder().encode(newValue)
        }
    }

    var topics: [DiscussionTopic] {
        get {
            guard let data = topicsData else { return [] }
            return (try? JSONDecoder().decode([DiscussionTopic].self, from: data)) ?? []
        }
        set {
            topicsData = try? JSONEncoder().encode(newValue)
        }
    }

    var speakerNames: [String: String] {
        get {
            guard let data = speakerNamesData else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            speakerNamesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 從逐字稿提取所有唯一說話者標籤（如 "A", "B"），保持出現順序
    var speakerLabels: [String] {
        guard let transcript else { return [] }
        let prefix = "[說話者 "
        var seen = Set<String>()
        var result: [String] = []
        for line in transcript.components(separatedBy: "\n") {
            if line.hasPrefix(prefix) {
                let afterPrefix = line.dropFirst(prefix.count)
                if let end = afterPrefix.firstIndex(of: "]") {
                    let label = String(afterPrefix[..<end])
                    if seen.insert(label).inserted { result.append(label) }
                }
            }
        }
        return result
    }
}

// MARK: - Meeting Status

enum MeetingStatus: String {
    case processing, complete, failed

    var displayText: String {
        switch self {
        case .processing: return "分析中..."
        case .complete:   return "完成"
        case .failed:     return "處理失敗"
        }
    }

    var isProcessing: Bool { self == .processing }
}

// MARK: - Next Step

struct NextStepItem: Codable, Identifiable {
    var id: UUID = UUID()
    var description: String
    var assignee: String?
    var dueDate: String?
    var isCompleted: Bool = false
    var priority: String? // "高" / "中" / "低"（AI 建議）
}

struct DiscussionTopic: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String   // 議題名稱
    var summary: String // 討論摘要
}

// MARK: - Time helper

extension Int {
    var formattedDuration: String {
        let h = self / 3600
        let m = (self % 3600) / 60
        let s = self % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
