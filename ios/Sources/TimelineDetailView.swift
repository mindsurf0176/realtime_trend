import SwiftUI
import Charts

@MainActor
@Observable
final class TimelineModel {
    var timeline: Timeline?
    var isLoading = false
    var error: String?

    func load(keyword: String) async {
        isLoading = timeline == nil
        error = nil
        do {
            timeline = try await APIClient.shared.timeline(keyword: keyword)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct TimelineDetailView: View {
    let keyword: String
    @State private var model = TimelineModel()
    @Environment(BookmarkStore.self) private var bookmarks

    private var points: [TimelinePoint] { model.timeline?.points ?? [] }

    /// 등장한 소스 목록 (범례/필터용).
    private var presentSources: [String] {
        var seen: [String] = []
        for p in points where !seen.contains(p.source) { seen.append(p.source) }
        return seen
    }

    var body: some View {
        ScrollView {
            if points.isEmpty {
                StatusOverlay(isLoading: model.isLoading,
                              error: model.error,
                              isEmpty: model.timeline != nil)
                    .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                VStack(spacing: 16) {
                    chartCard
                    summaryCard
                    newsButton
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(keyword)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let saved = bookmarks.isBookmarked(keyword)
                Button {
                    bookmarks.toggle(keyword, now: Int(Date().timeIntervalSince1970))
                } label: {
                    Image(systemName: saved ? "star.fill" : "star")
                        .foregroundStyle(saved ? .yellow : .secondary)
                }
                .accessibilityLabel(saved ? "북마크 해제" : "북마크")
            }
        }
        .task { await model.load(keyword: keyword) }
    }

    // MARK: - 차트

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("순위 추이").font(.headline)
            Chart(points) { p in
                LineMark(
                    x: .value("시각", p.date),
                    y: .value("순위", p.rank)
                )
                .foregroundStyle(by: .value("소스", SourceLabel.ko(p.source)))
                PointMark(
                    x: .value("시각", p.date),
                    y: .value("순위", p.rank)
                )
                .foregroundStyle(by: .value("소스", SourceLabel.ko(p.source)))
            }
            // 순위는 낮을수록(1위) 위로 오도록 y축 뒤집기
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) { Text("\(v)위") }
                    }
                }
            }
            .chartLegend(position: .bottom)
            .frame(height: 220)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 요약

    private var summaryCard: some View {
        let ranks = points.map(\.rank)
        let firstTs = points.map(\.ts).min()
        let lastTs = points.map(\.ts).max()
        return VStack(spacing: 0) {
            summaryRow("최고 순위", "\(ranks.min() ?? 0)위")
            Divider()
            summaryRow("관측 횟수", "\(Set(points.map(\.ts)).count)회")
            Divider()
            summaryRow("등장 소스", presentSources.map(SourceLabel.ko).joined(separator: ", "))
            if let firstTs {
                Divider(); summaryRow("첫 등장", relativeKo(firstTs))
            }
            if let lastTs {
                Divider(); summaryRow("최근", relativeKo(lastTs))
            }
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
        .padding(.vertical, 12)
    }

    // MARK: - 뉴스 버튼

    private var newsButton: some View {
        Link(destination: newsURL) {
            Label("관련 뉴스 검색", systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var newsURL: URL {
        let q = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://search.naver.com/search.naver?where=news&query=\(q)")!
    }
}
