import Foundation

/// 백엔드 API 클라이언트.
enum APIError: LocalizedError {
    case badURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "잘못된 주소"
        case .server(let m): return m
        }
    }
}

struct APIClient {
    static let shared = APIClient()

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var comps = URLComponents(url: Config.baseURL.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)
        if !query.isEmpty { comps?.queryItems = query }
        guard let url = comps?.url else { throw APIError.badURL }

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server("서버 응답 오류")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.server("데이터 해석 실패")
        }
    }

    func latest() async throws -> Latest {
        try await get("api/latest")
    }

    func issues(hours: Int) async throws -> IssuesResponse {
        try await get("api/issues", query: [URLQueryItem(name: "hours", value: String(hours))])
    }

    func timeline(keyword: String) async throws -> Timeline {
        try await get("api/timeline", query: [URLQueryItem(name: "keyword", value: keyword)])
    }
}
