import Foundation

enum APIError: LocalizedError {
    case noServerURL
    case noToken
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noServerURL:           return "請先在設定中填入伺服器網址"
        case .noToken:               return "請先登入"
        case .httpError(let c, let m): return "伺服器錯誤 \(c)：\(m)"
        case .decodingError(let e):  return "資料解析錯誤：\(e.localizedDescription)"
        case .networkError(let e):   return "網路錯誤：\(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private var baseURL: String {
        KeychainManager.serverURL ?? ""
    }

    // MARK: - Core request

    private func request<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Encodable? = nil,
        headers: [String: String] = [:],
        requiresAuth: Bool = true
    ) async throws -> T {
        guard !baseURL.isEmpty else { throw APIError.noServerURL }

        var urlRequest = URLRequest(url: URL(string: baseURL + path)!)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            guard let token = KeychainManager.accessToken else { throw APIError.noToken }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (k, v) in headers { urlRequest.setValue(v, forHTTPHeaderField: k) }

        if let body {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String ?? "未知錯誤"
            throw APIError.httpError(http.statusCode, msg)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Auth

    struct RegisterRequest: Encodable {
        let email: String
        let password: String
        let inviteCode: String
        let openaiApiKey: String
        let claudeApiKey: String
        enum CodingKeys: String, CodingKey {
            case email, password
            case inviteCode = "invite_code"
            case openaiApiKey = "openai_api_key"
            case claudeApiKey = "claude_api_key"
        }
    }

    func register(email: String, password: String, inviteCode: String, openaiKey: String, claudeKey: String) async throws -> TokenResponse {
        try await request(path: "/auth/register", method: "POST",
                          body: RegisterRequest(email: email, password: password, inviteCode: inviteCode,
                                                openaiApiKey: openaiKey, claudeApiKey: claudeKey),
                          requiresAuth: false)
    }

    func login(email: String, password: String) async throws -> TokenResponse {
        struct LoginBody: Encodable { let email: String; let password: String }
        return try await request(path: "/auth/login", method: "POST",
                                 body: LoginBody(email: email, password: password),
                                 requiresAuth: false)
    }

    func getMe() async throws -> UserResponse {
        try await request(path: "/auth/me")
    }

    func updateAPIKeys(openaiKey: String?, claudeKey: String?) async throws {
        struct KeysBody: Encodable {
            let openaiApiKey: String?
            let claudeApiKey: String?
            enum CodingKeys: String, CodingKey {
                case openaiApiKey = "openai_api_key"
                case claudeApiKey = "claude_api_key"
            }
        }
        struct Empty: Decodable {}
        let _: Empty = try await request(path: "/auth/api-keys", method: "PUT",
                                          body: KeysBody(openaiApiKey: openaiKey, claudeApiKey: claudeKey))
    }

    // MARK: - Meetings

    func listMeetings() async throws -> [Meeting] {
        try await request(path: "/meetings")
    }

    struct CreateMeetingRequest: Encodable {
        let startedAt: Date
        let title: String?
        enum CodingKeys: String, CodingKey {
            case title
            case startedAt = "started_at"
        }
    }

    func createMeeting(startedAt: Date, title: String? = nil) async throws -> Meeting {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var req = URLRequest(url: URL(string: baseURL + "/meetings")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainManager.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try encoder.encode(CreateMeetingRequest(startedAt: startedAt, title: title))
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(Meeting.self, from: data)
    }

    func uploadAudio(meetingId: String, audioURL: URL) async throws {
        guard !baseURL.isEmpty else { throw APIError.noServerURL }
        guard let token = KeychainManager.accessToken else { throw APIError.noToken }

        var req = URLRequest(url: URL(string: "\(baseURL)/meetings/\(meetingId)/audio")!)
        req.httpMethod = "POST"

        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var body = Data()
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode, "音檔上傳失敗")
        }
    }

    func getMeetingStatus(meetingId: String) async throws -> MeetingStatusResponse {
        try await request(path: "/meetings/\(meetingId)/status")
    }

    func getMeetingResult(meetingId: String) async throws -> MeetingResult {
        try await request(path: "/meetings/\(meetingId)/result")
    }

    func deleteMeeting(meetingId: String) async throws {
        guard !baseURL.isEmpty else { throw APIError.noServerURL }
        guard let token = KeychainManager.accessToken else { throw APIError.noToken }
        var req = URLRequest(url: URL(string: "\(baseURL)/meetings/\(meetingId)")!)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        try await URLSession.shared.data(for: req)
    }

    func updateNextStep(meetingId: String, stepIndex: Int, isCompleted: Bool) async throws {
        struct Body: Encodable { let isCompleted: Bool; enum CodingKeys: String, CodingKey { case isCompleted = "is_completed" } }
        struct Empty: Decodable {}
        let _: Empty = try await request(
            path: "/meetings/\(meetingId)/nextsteps/\(stepIndex)",
            method: "PATCH",
            body: Body(isCompleted: isCompleted)
        )
    }
}
