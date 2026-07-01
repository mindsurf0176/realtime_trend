# 이슈박스 (IssueBox)

각 포털의 실시간 검색어/이슈를 한데 모아 통합 순위로 보여주고, 시간별로 아카이브해
"이 이슈 언제부터 떴나"를 추적하는 앱.

네이버·다음은 실검 서비스를 폐지해 원본이 없으므로, 아직 데이터를 제공하는 소스만 사용한다.

## 소스

- **구글 트렌드** (한국, 공식 RSS) — 검색량 실측 기반
- **시그널 실검** (여러 소스 집계, JSON API) — 비공식
- **네이트 실시간 이슈 키워드** (AI 뉴스 기반, HTML)

## 구조

```
realtime-trends/
  sources.py           소스 수집 로직 (공용, 표준 라이브러리만)
  trends.py            CLI 조회기
  backend/
    server.py          수집기(주기 실행) + SQLite 저장 + JSON API
  ios/
    project.yml        XcodeGen 프로젝트 정의
    Sources/           SwiftUI 앱 (이슈박스)
  Procfile             Railway 배포용 (web: python backend/server.py)
  requirements.txt     (빈 파일 — 파이썬 인식용)
```

수집은 폰이 아니라 서버가 24시간 돌린다. 그래야 앱이 꺼져 있어도 타임라인이 끊기지 않는다.

## 백엔드

### 로컬 실행
```bash
python3 backend/server.py
# 환경변수: PORT(기본 8000), DB_PATH(기본 backend/issues.db), INTERVAL_SEC(기본 600)
```

### API
- `GET /api/latest` — 최신 스냅샷 (통합 + 소스별)
- `GET /api/timeline?keyword=X` — 특정 키워드의 시각별 순위 추이
- `GET /api/issues?hours=48` — 기간 내 이슈 목록 (첫등장·최종·최고순위)
- `GET /api/health`

### Railway 배포
1. 이 리포를 GitHub에 올리고 Railway에서 새 프로젝트로 연결 (Nixpacks가 자동 인식).
2. **Volume**을 붙이고 마운트 경로를 `/data`로 지정.
3. 환경변수 `DB_PATH=/data/issues.db` 설정 (재배포해도 데이터 유지).
4. 배포 후 URL을 iOS 앱 `Sources/Config.swift`의 `baseURL`에 넣는다.

> 볼륨 없이 배포하면 재배포마다 SQLite가 초기화돼 타임라인이 리셋된다. 반드시 볼륨을 붙일 것.

## iOS 앱

### 실행
```bash
cd ios
xcodegen generate            # IssueBox.xcodeproj 생성
open IssueBox.xcodeproj      # Xcode에서 실행 (⌘R)
```

- 화면: **실시간**(통합/구글/시그널/네이트 세그먼트) + **아카이브**(기간별 이슈 목록)
- 행을 탭하면 **타임라인 상세**(순위 추이 차트 + 요약 + 뉴스 검색)
- `Config.swift`의 `baseURL`을 백엔드 주소로 맞출 것
  - 시뮬레이터 + 로컬 서버: `http://127.0.0.1:8777`
  - 실기기/배포: Railway https 주소

### 알려진 이슈
- iOS 26에서 `List`를 `NavigationStack`의 직접 루트로 두면 렌더가 깨진다.
  타임라인 화면은 `ScrollView` 기반으로 우회했다. 새 화면 추가 시 주의.
