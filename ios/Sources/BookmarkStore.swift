import Foundation

/// 사용자가 저장한 관심 이슈.
struct Bookmark: Codable, Identifiable, Hashable {
    let keyword: String
    let savedAt: Int   // unix seconds

    var id: String { keyword }
}

/// 북마크 저장소. 기기 로컬(UserDefaults)에 JSON으로 보관 — 서버 불필요, 오프라인 동작.
@MainActor
@Observable
final class BookmarkStore {
    private let key = "issuebox.bookmarks.v1"
    private(set) var items: [Bookmark] = []

    init() { load() }

    func isBookmarked(_ keyword: String) -> Bool {
        items.contains { $0.keyword == keyword }
    }

    func toggle(_ keyword: String, now: Int) {
        if isBookmarked(keyword) {
            items.removeAll { $0.keyword == keyword }
        } else {
            items.insert(Bookmark(keyword: keyword, savedAt: now), at: 0)
        }
        save()
    }

    func remove(_ keyword: String) {
        items.removeAll { $0.keyword == keyword }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Bookmark].self, from: data)
        else { return }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
