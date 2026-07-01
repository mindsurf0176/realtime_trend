import SwiftUI

struct BookmarkView: View {
    @Environment(BookmarkStore.self) private var bookmarks

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.items.isEmpty {
                    ContentUnavailableView(
                        "저장한 이슈가 없어요",
                        systemImage: "star",
                        description: Text("이슈 상세 화면 오른쪽 위 별을 눌러 저장하세요.")
                    )
                } else {
                    List {
                        ForEach(bookmarks.items) { bm in
                            NavigationLink(value: bm.keyword) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bm.keyword)
                                        .font(.body.weight(.medium))
                                        .lineLimit(2)
                                    Text("\(relativeKo(bm.savedAt)) 저장")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { idx in
                            for i in idx { bookmarks.remove(bookmarks.items[i].keyword) }
                        }
                    }
                }
            }
            .navigationTitle("북마크")
            .navigationDestination(for: String.self) { kw in
                TimelineDetailView(keyword: kw)
            }
        }
    }
}
