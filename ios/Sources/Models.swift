import Foundation

/// 소스별 한 항목. 소스마다 채워지는 필드가 달라 대부분 옵셔널이다.
struct Entry: Codable, Identifiable, Hashable {
    let rank: Int
    let keyword: String
    let traffic: String?      // google
    let state: String?        // signal (상승/하락/신규/유지)
    let score: Double?        // combined
    let sources: [String]?    // combined (어떤 소스에서 왔는지)

    var id: String { "\(keyword)-\(rank)" }
}

/// /api/latest 응답.
struct Latest: Codable {
    let ts: Int?
    let google: [Entry]
    let signal: [Entry]
    let nate: [Entry]
    let combined: [Entry]
}

/// /api/issues 응답의 한 이슈.
struct Issue: Codable, Identifiable, Hashable {
    let keyword: String
    let firstSeen: Int
    let lastSeen: Int
    let peakRank: Int
    let appearances: Int
    let sources: [String]

    var id: String { keyword }

    enum CodingKeys: String, CodingKey {
        case keyword
        case firstSeen = "first_seen"
        case lastSeen = "last_seen"
        case peakRank = "peak_rank"
        case appearances
        case sources
    }
}

struct IssuesResponse: Codable {
    let hours: Int
    let issues: [Issue]
}

/// /api/timeline 응답의 한 포인트.
struct TimelinePoint: Codable, Identifiable, Hashable {
    let ts: Int
    let source: String
    let rank: Int
    let keyword: String

    var id: String { "\(ts)-\(source)" }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }
}

struct Timeline: Codable {
    let keyword: String
    let points: [TimelinePoint]
}

/// 소스 이름을 한글 라벨로.
enum SourceLabel {
    static func ko(_ s: String) -> String {
        switch s {
        case "google": return "구글"
        case "signal": return "시그널"
        case "nate": return "네이트"
        case "combined": return "통합"
        default: return s
        }
    }
}
