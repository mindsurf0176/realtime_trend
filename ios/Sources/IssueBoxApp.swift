import SwiftUI

@main
struct IssueBoxApp: App {
    @State private var bookmarks = BookmarkStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(bookmarks)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            LiveView()
                .tabItem { Label("실시간", systemImage: "bolt.fill") }
            ArchiveView()
                .tabItem { Label("아카이브", systemImage: "archivebox.fill") }
            BookmarkView()
                .tabItem { Label("북마크", systemImage: "star.fill") }
        }
    }
}
