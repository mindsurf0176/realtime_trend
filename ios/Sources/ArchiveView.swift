import SwiftUI

@MainActor
@Observable
final class ArchiveModel {
    var issues: [Issue] = []
    var isLoading = false
    var error: String?
    var hours = 48

    func load() async {
        isLoading = issues.isEmpty
        error = nil
        do {
            issues = try await APIClient.shared.issues(hours: hours).issues
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct ArchiveView: View {
    @State private var model = ArchiveModel()

    private let ranges: [(String, Int)] = [("24시간", 24), ("48시간", 48), ("7일", 168)]

    var body: some View {
        NavigationStack {
            Group {
                if model.issues.isEmpty {
                    StatusOverlay(isLoading: model.isLoading,
                                  error: model.error,
                                  isEmpty: !model.isLoading && model.error == nil)
                } else {
                    List {
                        Section {
                            ForEach(model.issues) { issue in
                                NavigationLink(value: issue.keyword) {
                                    IssueRow(issue: issue)
                                }
                            }
                        } header: {
                            Text("\(model.issues.count)개 이슈")
                        }
                    }
                }
            }
            .navigationTitle("이슈 아카이브")
            .navigationDestination(for: String.self) { kw in
                TimelineDetailView(keyword: kw)
            }
            .safeAreaInset(edge: .top) {
                Picker("기간", selection: $model.hours) {
                    ForEach(ranges, id: \.1) { Text($0.0).tag($0.1) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 6)
                .background(.bar)
                .onChange(of: model.hours) { _, _ in
                    Task { await model.load() }
                }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }
}

struct IssueRow: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(issue.keyword)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Spacer()
                Text("최고 \(issue.peakRank)위")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(issue.sources, id: \.self) { SourceBadge(source: $0) }
                Spacer()
                Text("\(relativeKo(issue.firstSeen)) 등장")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
