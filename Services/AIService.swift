import Foundation

// MARK: - 錯誤類型

enum AIError: LocalizedError {
    case noAPIKey(String)
    case networkError(Error)
    case httpError(Int, String)
    case decodingError
    case emptyResponse
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let name):
            return "請先在設定中填入 \(name)"
        case .networkError(let e):
            return "網路連線失敗：\(e.localizedDescription)"
        case .httpError(let code, let msg):
            return "API 錯誤（\(code)）：\(msg)"
        case .decodingError:
            return "回應格式錯誤，請稍後再試"
        case .emptyResponse:
            return "AI 回應為空，請稍後再試"
        case .transcriptionFailed(let msg):
            return "語音辨識失敗：\(msg)"
        }
    }
}

// MARK: - AI Service（AssemblyAI 語音辨識 + Claude 摘要）

final class AIService {
    static let shared = AIService()
    private init() {}

    // MARK: - 語音轉文字 + 說話者辨識（AssemblyAI）

    func transcribe(audioURL: URL) async throws -> String {
        guard let apiKey = KeychainManager.assemblyaiKey, !apiKey.isEmpty else {
            throw AIError.noAPIKey("AssemblyAI API Key")
        }

        // Step 1：上傳音檔到 AssemblyAI
        let uploadedURL = try await uploadAudio(fileURL: audioURL, apiKey: apiKey)

        // Step 2：送出辨識請求（開啟說話者辨識）
        let transcriptID = try await requestTranscription(audioURL: uploadedURL, apiKey: apiKey)

        // Step 3：輪詢直到完成
        return try await pollTranscription(id: transcriptID, apiKey: apiKey)
    }

    private func uploadAudio(fileURL: URL, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/upload")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Data(contentsOf: fileURL)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw AIError.httpError(http.statusCode, "音檔上傳失敗")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uploadURL = json["upload_url"] as? String else {
            throw AIError.decodingError
        }
        return uploadURL
    }

    private func requestTranscription(audioURL: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "audio_url": audioURL,
            "speaker_labels": true,       // 開啟說話者辨識
            "language_detection": true    // 自動偵測中英混合
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "未知錯誤"
            throw AIError.httpError(http.statusCode, detail)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw AIError.decodingError
        }
        return id
    }

    private func pollTranscription(id: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.assemblyai.com/v2/transcript/\(id)")!)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        // 最多等 15 分鐘（180 次 × 5 秒）
        for _ in 0..<180 {
            try await Task.sleep(nanoseconds: 5_000_000_000)

            let (data, _): (Data, URLResponse)
            do {
                (data, _) = try await URLSession.shared.data(for: request)
            } catch {
                throw AIError.networkError(error)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AIError.decodingError
            }

            switch json["status"] as? String ?? "" {
            case "completed":
                // 優先使用 utterances（含說話者標籤）
                if let utterances = json["utterances"] as? [[String: Any]], !utterances.isEmpty {
                    let lines = utterances.compactMap { u -> String? in
                        guard let speaker = u["speaker"] as? String,
                              let text = u["text"] as? String else { return nil }
                        return "[說話者 \(speaker)]: \(text)"
                    }
                    return lines.joined(separator: "\n")
                }
                // 降級：回傳純文字
                return json["text"] as? String ?? ""

            case "error":
                throw AIError.transcriptionFailed(json["error"] as? String ?? "語音辨識失敗")

            default:
                continue // queued / processing，繼續等待
            }
        }

        throw AIError.transcriptionFailed("辨識逾時，請確認音檔長度不超過 2 小時")
    }

    // MARK: - 會議摘要（Claude API）

    struct SummaryResult {
        let title: String
        let points: [String]
        let nextSteps: [NextStepItem]
    }

    func summarize(transcript: String) async throws -> SummaryResult {
        guard let apiKey = KeychainManager.claudeKey, !apiKey.isEmpty else {
            throw AIError.noAPIKey("Claude API Key")
        }

        let prompt = """
        你是一個專業的會議記錄助理，擅長處理繁體中文和英文混合的商業會議。

        以下逐字稿已標記不同說話者（[說話者 A]、[說話者 B] 等），請在分析時考慮各說話者的立場與發言內容。

        根據以下會議逐字稿，產生一個 JSON，格式如下（只回傳 JSON，不要任何其他文字）：

        {
          "title": "用一句話描述這場會議的主題（繁體中文，15字以內）",
          "summary": [
            "重點一（一句話，繁體中文，可提及是哪位說話者提出的）",
            "重點二",
            "重點三",
            "重點四",
            "重點五",
            "重點六",
            "重點七",
            "重點八",
            "重點九",
            "重點十"
          ],
          "next_steps": [
            {
              "description": "行動項目描述（繁體中文）",
              "assignee": "負責人（若逐字稿中可判斷是哪位說話者則填入，否則填 null）",
              "due_date": "截止日期或 null"
            }
          ]
        }

        規則：
        - summary 必須正好 10 點，不足的用「（本次會議無此項重點）」補足
        - next_steps 從逐字稿提取具體待辦事項，沒有就回傳空陣列 []
        - 技術術語或英文專有名詞可保留英文

        逐字稿：
        \(transcript)
        """

        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 3000,
            "messages": [["role": "user", "content": prompt]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let detail = msg?["message"] as? String ?? "未知錯誤"
            throw AIError.httpError(http.statusCode, detail)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let rawText = content["text"] as? String else {
            throw AIError.decodingError
        }

        var cleanText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.hasPrefix("```") {
            cleanText = cleanText
                .replacingOccurrences(of: "^```(?:json)?\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*```$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let resultData = cleanText.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: resultData) as? [String: Any] else {
            throw AIError.decodingError
        }

        var points = result["summary"] as? [String] ?? []
        while points.count < 10 { points.append("（本次會議無此項重點）") }
        points = Array(points.prefix(10))

        let rawSteps = result["next_steps"] as? [[String: Any]] ?? []
        let steps = rawSteps.map { step in
            NextStepItem(
                description: step["description"] as? String ?? "",
                assignee: step["assignee"] as? String,
                dueDate: step["due_date"] as? String,
                isCompleted: false
            )
        }

        return SummaryResult(
            title: result["title"] as? String ?? "會議記錄",
            points: points,
            nextSteps: steps
        )
    }
}
