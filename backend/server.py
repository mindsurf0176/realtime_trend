#!/usr/bin/env python3
"""실시간 이슈 아카이브 백엔드.

- 10분마다 세 소스를 수집해 SQLite에 시각별 스냅샷으로 누적 (타임라인의 원천)
- iOS 앱이 소비할 JSON API 제공
- 표준 라이브러리만 사용 → Railway 등에 python 하나로 배포 가능

환경변수:
  PORT           서버 포트 (기본 8000)
  DB_PATH        SQLite 파일 경로 (기본 ./issues.db, Railway는 볼륨 경로 지정)
  INTERVAL_SEC   수집 주기 초 (기본 600 = 10분)

엔드포인트:
  GET /api/latest              최신 스냅샷 (통합 + 소스별)
  GET /api/timeline?keyword=X  특정 키워드의 시각별 순위 추이
  GET /api/issues?hours=48     기간 내 이슈 목록 (첫등장·최종·최고순위)
  GET /api/health              상태
"""
import json
import os
import sqlite3
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import sources  # noqa: E402

DB_PATH = os.environ.get("DB_PATH", os.path.join(os.path.dirname(__file__), "issues.db"))
PORT = int(os.environ.get("PORT", "8000"))
INTERVAL_SEC = int(os.environ.get("INTERVAL_SEC", "600"))

_db_lock = threading.Lock()


def db():
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    with db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS snapshots (
                ts     INTEGER NOT NULL,   -- 수집 시각 (unix seconds)
                source TEXT    NOT NULL,   -- google | signal | nate | combined
                rank   INTEGER NOT NULL,   -- 1부터
                keyword TEXT   NOT NULL,
                norm   TEXT    NOT NULL,   -- 정규화 키 (소스간 매칭용)
                extra  TEXT                -- json: traffic/state/score/sources
            )
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_ts ON snapshots(ts)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_norm ON snapshots(norm)")


def store_snapshot(data, ts):
    """collect() 결과를 스냅샷 행들로 저장."""
    rows = []

    def add(source, rank, keyword, extra):
        rows.append((ts, source, rank, keyword, sources.normalize(keyword),
                     json.dumps(extra, ensure_ascii=False)))

    for i, it in enumerate(data.get("google", []), 1):
        add("google", i, it["keyword"], {"traffic": it.get("traffic", "")})
    for it in data.get("signal", []):
        add("signal", it["rank"], it["keyword"], {"state": it.get("state", "")})
    for i, kw in enumerate(data.get("nate", []), 1):
        add("nate", i, kw, {})
    for i, it in enumerate(data.get("combined", []), 1):
        add("combined", i, it["keyword"],
            {"score": it.get("score"), "sources": it.get("sources", [])})

    with _db_lock, db() as conn:
        conn.executemany(
            "INSERT INTO snapshots (ts, source, rank, keyword, norm, extra) "
            "VALUES (?, ?, ?, ?, ?, ?)", rows)


def collect_once():
    data = sources.collect()
    ts = int(time.time())
    store_snapshot(data, ts)
    n = len(data.get("combined", []))
    err = data.get("errors") or {}
    print(f"[collect] ts={ts} combined={n} errors={list(err)}", flush=True)
    return ts


def collector_loop():
    while True:
        try:
            collect_once()
        except Exception as e:
            print(f"[collect] FAILED: {e}", flush=True)
        time.sleep(INTERVAL_SEC)


# ---- API 조회 ----

def api_latest():
    with db() as conn:
        row = conn.execute("SELECT MAX(ts) AS ts FROM snapshots").fetchone()
        if not row or row["ts"] is None:
            return {"ts": None, "google": [], "signal": [], "nate": [], "combined": []}
        ts = row["ts"]
        out = {"ts": ts, "google": [], "signal": [], "nate": [], "combined": []}
        for r in conn.execute(
                "SELECT source, rank, keyword, extra FROM snapshots "
                "WHERE ts=? ORDER BY source, rank", (ts,)):
            extra = json.loads(r["extra"] or "{}")
            out.setdefault(r["source"], []).append(
                {"rank": r["rank"], "keyword": r["keyword"], **extra})
        return out


def api_timeline(keyword):
    norm = sources.normalize(keyword)
    with db() as conn:
        rows = conn.execute(
            "SELECT ts, source, rank, keyword FROM snapshots "
            "WHERE norm=? AND source!='combined' ORDER BY ts", (norm,)).fetchall()
    return {
        "keyword": keyword,
        "points": [
            {"ts": r["ts"], "source": r["source"], "rank": r["rank"], "keyword": r["keyword"]}
            for r in rows
        ],
    }


def api_issues(hours):
    since = int(time.time()) - hours * 3600
    with db() as conn:
        rows = conn.execute("""
            SELECT norm,
                   MIN(ts) AS first_seen,
                   MAX(ts) AS last_seen,
                   MIN(rank) AS peak_rank,
                   COUNT(DISTINCT ts) AS appearances,
                   (SELECT keyword FROM snapshots s2
                     WHERE s2.norm = s1.norm AND s2.ts >= ?
                     ORDER BY s2.ts DESC LIMIT 1) AS keyword,
                   (SELECT GROUP_CONCAT(DISTINCT source) FROM snapshots s3
                     WHERE s3.norm = s1.norm AND s3.ts >= ? AND s3.source != 'combined') AS srcs
            FROM snapshots s1
            WHERE ts >= ? AND source != 'combined'
            GROUP BY norm
            ORDER BY last_seen DESC, appearances DESC
        """, (since, since, since)).fetchall()
    return {
        "hours": hours,
        "issues": [
            {
                "keyword": r["keyword"],
                "first_seen": r["first_seen"],
                "last_seen": r["last_seen"],
                "peak_rank": r["peak_rank"],
                "appearances": r["appearances"],
                "sources": (r["srcs"] or "").split(",") if r["srcs"] else [],
            }
            for r in rows
        ],
    }


class Handler(BaseHTTPRequestHandler):
    def _send(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        try:
            if u.path == "/api/health":
                self._send({"ok": True, "interval_sec": INTERVAL_SEC})
            elif u.path == "/api/latest":
                self._send(api_latest())
            elif u.path == "/api/timeline":
                kw = (q.get("keyword") or [""])[0]
                if not kw:
                    return self._send({"error": "keyword required"}, 400)
                self._send(api_timeline(kw))
            elif u.path == "/api/issues":
                hours = int((q.get("hours") or ["48"])[0])
                self._send(api_issues(hours))
            else:
                self._send({"error": "not found"}, 404)
        except Exception as e:
            self._send({"error": str(e)}, 500)

    def log_message(self, *a):  # 기본 접근로그 소음 억제
        pass


def main():
    init_db()
    # 시작 시 즉시 1회 수집 (DB가 비어있지 않도록)
    try:
        collect_once()
    except Exception as e:
        print(f"[startup collect] {e}", flush=True)
    threading.Thread(target=collector_loop, daemon=True).start()
    srv = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"listening on :{PORT}  db={DB_PATH}  interval={INTERVAL_SEC}s", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
