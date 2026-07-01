import Foundation

/// 백엔드 주소 설정.
///
/// - 시뮬레이터: 맥에서 로컬 서버를 띄웠다면 http://127.0.0.1:8777 로 접속 가능.
/// - 실기기/배포: Railway에 배포한 https 주소로 바꿀 것.
enum Config {
    /// 배포 시 이 값만 Railway 주소로 교체하면 된다.
    static let baseURL = URL(string: "http://127.0.0.1:8777")!
}
