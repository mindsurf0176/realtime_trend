import SwiftUI

/// 소스 뱃지 (구글/시그널/네이트).
struct SourceBadge: View {
    let source: String

    private var color: Color {
        switch source {
        case "google": return .blue
        case "signal": return .orange
        case "nate": return .purple
        default: return .gray
        }
    }

    var body: some View {
        Text(SourceLabel.ko(source))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

/// 순위 변화 상태 뱃지 (시그널의 상승/하락/신규).
struct StateBadge: View {
    let state: String

    private var symbol: String {
        switch state {
        case "상승": return "arrow.up"
        case "하락": return "arrow.down"
        case "신규": return "sparkle"
        default: return "minus"
        }
    }
    private var color: Color {
        switch state {
        case "상승": return .red
        case "하락": return .blue
        case "신규": return .green
        default: return .secondary
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
    }
}

/// 순위 원형 번호.
struct RankBadge: View {
    let rank: Int
    var body: some View {
        Text("\(rank)")
            .font(.subheadline.weight(.bold).monospacedDigit())
            .foregroundStyle(rank <= 3 ? .white : .primary)
            .frame(width: 26, height: 26)
            .background(rank <= 3 ? Color.accentColor : Color(.systemGray5))
            .clipShape(Circle())
    }
}

/// unix seconds -> "3분 전" 형태.
func relativeKo(_ ts: Int) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(ts))
    let f = RelativeDateTimeFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.unitsStyle = .short
    return f.localizedString(for: date, relativeTo: Date())
}

/// 로딩/에러/빈 상태 공용 오버레이.
struct StatusOverlay: View {
    let isLoading: Bool
    let error: String?
    let isEmpty: Bool

    var body: some View {
        if isLoading {
            ProgressView()
        } else if let error {
            ContentUnavailableView("불러오지 못했어요", systemImage: "wifi.slash", description: Text(error))
        } else if isEmpty {
            ContentUnavailableView("아직 수집된 이슈가 없어요", systemImage: "hourglass")
        }
    }
}
