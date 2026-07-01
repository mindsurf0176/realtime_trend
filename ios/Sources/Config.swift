import Foundation

/// 백엔드 주소 설정.
///
/// - 시뮬레이터: 맥에서 로컬 서버를 띄웠다면 http://127.0.0.1:8777 로 접속 가능.
/// - 실기기/배포: Railway에 배포한 https 주소로 바꿀 것.
enum Config {
    /// 프로덕션 백엔드 (Railway). 로컬 서버 없이 바로 동작한다.
    static let baseURL = URL(string: "https://issuebox-backend-production.up.railway.app")!

    /// 로컬 개발 시에는 위를 주석 처리하고 아래를 사용:
    // static let baseURL = URL(string: "http://127.0.0.1:8777")!
}
