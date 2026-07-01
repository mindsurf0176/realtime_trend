import SwiftUI

@MainActor
@Observable
final class LiveModel {
    var latest: Latest?
    var isLoading = false
    var error: String?

    func load() async {
        isLoading = latest == nil
        error = nil
        do {
            latest = try await APIClient.shared.latest()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

enum LiveTab: String, CaseIterable, Identifiable {
    case combined, google, signal, nate
    var id: String { rawValue }
    var label: String {
        switch self {
        case .combined: return "통합"
        case .google: return "구글"
        case .signal: return "시그널"
        case .nate: return "네이트"
        }
    }
}

struct LiveView: View {
    @State private var model = LiveModel()
    @State private var tab: LiveTab = .combined

    private var entries: [Entry] {
        guard let l = model.latest else { return [] }
        switch tab {
        case .combined: return l.combined
        case .google: return l.google
        case .signal: return l.signal
        case .nate: return l.nate
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    StatusOverlay(isLoading: model.isLoading,
                                  error: model.error,
                                  isEmpty: model.latest != nil)
                } else {
                    List {
                        Section {
                            ForEach(entries) { entry in
                                NavigationLink(value: entry.keyword) {
                                    EntryRow(entry: entry)
                                }
                            }
                        } header: {
                            if let ts = model.latest?.ts {
                                Text("\(relativeKo(ts)) 기준")
                            }
                        }
                    }
                }
            }
            .navigationTitle("실시간 이슈")
            .navigationDestination(for: String.self) { kw in
                TimelineDetailView(keyword: kw)
            }
            .safeAreaInset(edge: .top) {
                Picker("소스", selection: $tab) {
                    ForEach(LiveTab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 6)
                .background(.bar)
            }
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: entry.rank)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.keyword)
                    .font(.body)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let sources = entry.sources {
                        ForEach(sources, id: \.self) { SourceBadge(source: $0) }
                    }
                    if let traffic = entry.traffic, !traffic.isEmpty {
                        Text(traffic).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let state = entry.state {
                StateBadge(state: state)
            }
        }
        .padding(.vertical, 2)
    }
}
