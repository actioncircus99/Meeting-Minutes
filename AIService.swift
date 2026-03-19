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
            "speech_models": ["universal-2"], // 指定語音模型（複數陣列）
            "speaker_labels": true,           // 開啟說話者辨識
            "language_detection": true        // 自動偵測中英混合
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
        let topics: [DiscussionTopic]
        let nextSteps: [NextStepItem]
    }

    func summarize(transcript: String) async throws -> SummaryResult {
        guard let apiKey = KeychainManager.claudeKey, !apiKey.isEmpty else {
            throw AIError.noAPIKey("Claude API Key")
        }

        let prompt = """
        你是一位有十五年經驗的資深企業秘書，剛剛旁聽完這場會議。你的任務是替**沒有參加這場會議的人**撰寫一份清晰易懂的會議摘要。

        讀者完全不了解會議背景，你需要讓他們讀完後立刻明白：這場會議決定了什麼、討論了什麼、接下來誰要做什麼。

        以下逐字稿標記了不同說話者（[說話者 A]、[說話者 B] 等）。若有使用者定義的名稱（如 [老闆]、[工程師]），請直接使用該名稱。

        ---

        【重要寫作規則】

        1. **說話者融入句子，禁用括號**
           - ❌ 錯誤：「需要重新評估時程（說話者 A 提出）」
           - ✅ 正確：「說話者 A 認為目前時程過於緊湊，建議重新評估」
           - 用動詞自然帶出主詞：「指出」「決定」「建議」「提醒」「強調」「認為」

        2. **結論寫完整句子，說清楚「誰決定了什麼、為什麼」**
           - ❌ 錯誤：「確認採用新方案」
           - ✅ 正確：「會議決定採用新方案，主要原因是舊系統維護成本過高」

        3. **討論摘要用段落敘述，不用條列**
           - 寫法像是一位觀察者在描述這場討論，有起因、有爭論、有結果
           - 同一人連續發言可用「他」「她」代替重複名字

        4. **行動項目用主動句**
           - ❌ 錯誤：「整理報告」
           - ✅ 正確：「說話者 B 負責在下週五前整理完整的成本分析報告」

        5. **避免 AI 感的詞彙**
           - 不要用：「值得注意的是」「綜上所述」「不容否認」「顯而易見」「基於以上」

        ---

        請根據以上規則，輸出以下 JSON 格式（只回傳 JSON，不要其他文字）：

        {
          "title": "這場會議的主題（15字以內，讓沒參加的人一眼看懂在討論什麼）",
          "conclusions": [
            "完整一句話描述一個決議，說清楚誰決定了什麼、原因是什麼",
            "第二個決議（依此類推，2-5個）"
          ],
          "topics": [
            {
              "title": "議題名稱（6字以內）",
              "summary": "用 2-4 句流暢的段落描述這個議題：從為什麼討論這件事開始，說明各方的立場或顧慮，最後帶出這個議題的結論或共識。說話者名字自然融入句子，不用括號。"
            }
          ],
          "next_steps": [
            {
              "description": "主動句描述：說話者 X 負責在 Y 時間前完成 Z 事項",
              "assignee": "負責人名稱（從逐字稿判斷，否則填 null）",
              "due_date": "截止日期（如有提及）或 null",
              "priority": "高、中、或低（依緊急程度與對會議目標的影響判斷）"
            }
          ]
        }

        規則：
        - conclusions：2-5 個，沒有明確決議就寫「本次會議聚焦於討論，尚未形成明確決議」
        - topics：依實際討論議題拆分，最多 8 個，沒有明確議題就合併成一個
        - next_steps：有具體待辦才列，沒有就回傳空陣列 []
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

        let points = Array((result["conclusions"] as? [String] ?? []).prefix(5))

        let rawTopics = result["topics"] as? [[String: Any]] ?? []
        let topics = Array(rawTopics.prefix(8).map { t in
            DiscussionTopic(
                title: t["title"] as? String ?? "",
                summary: t["summary"] as? String ?? ""
            )
        })

        let rawSteps = result["next_steps"] as? [[String: Any]] ?? []
        let steps = rawSteps.map { step in
            NextStepItem(
                description: step["description"] as? String ?? "",
                assignee: step["assignee"] as? String,
                dueDate: step["due_date"] as? String,
                isCompleted: false,
                priority: step["priority"] as? String
            )
        }

        return SummaryResult(
            title: result["title"] as? String ?? "會議記錄",
            points: points,
            topics: topics,
            nextSteps: steps
        )
    }
}
