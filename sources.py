"""실시간 검색어 소스 수집 로직 (공용 모듈).

CLI(trends.py)와 백엔드 서버(backend/server.py)가 함께 사용한다.
표준 라이브러리만 사용.

소스:
  - Google Trends (한국, 공식 RSS)
  - Signal 실검 (여러 소스 집계, JSON API)
  - Nate 실시간 이슈 키워드 (AI 뉴스 기반, HTML)
네이버/다음은 실검 서비스를 폐지해 원본이 없으므로 제외.
"""
import json
import re
import urllib.request
from collections import defaultdict
from html import unescape
from xml.etree import ElementTree

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
TIMEOUT = 10

GOOGLE_URL = "https://trends.google.co.kr/trending/rss?geo=KR"
SIGNAL_URL = "https://api.signal.bz/news/realtime"
NATE_URL = "https://www.nate.com/"


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read().decode("utf-8", "replace")


def fetch_google():
    """-> [{keyword, traffic}, ...]"""
    xml = _get(GOOGLE_URL)
    root = ElementTree.fromstring(xml)
    ns = {"ht": "https://trends.google.com/trending/rss"}
    out = []
    for item in root.iter("item"):
        title = item.findtext("title", "").strip()
        traffic = item.findtext("ht:approx_traffic", "", ns).strip()
        if title:
            out.append({"keyword": title, "traffic": traffic})
    return out


def fetch_signal():
    """-> [{rank, keyword, state}, ...]"""
    data = json.loads(_get(SIGNAL_URL))
    state_map = {"+": "상승", "-": "하락", "n": "신규", "s": "유지"}
    return [
        {
            "rank": it["rank"],
            "keyword": it["keyword"],
            "state": state_map.get(it.get("state", ""), it.get("state", "")),
        }
        for it in data.get("top10", [])
    ]


def fetch_nate():
    """-> [keyword, ...]
    슬라이더가 항목을 중복 렌더링하므로 순위(num_rank)와 키워드(txt_rank)를
    쌍으로 묶어 순위별로 중복 제거한다."""
    html = _get(NATE_URL)
    pairs = re.findall(
        r'class="num_rank">(\d+)</span>.*?class="txt_rank"[^>]*>(.*?)</span>',
        html, re.S,
    )
    seen = {}
    for rank, kw in pairs:
        r = int(rank)
        kw = unescape(re.sub(r"<[^>]+>", "", kw)).strip()
        if kw and r not in seen:
            seen[r] = kw
    return [seen[r] for r in sorted(seen)][:10]


def normalize(kw):
    """서로 다른 소스의 키워드를 대략 매칭하기 위한 정규화."""
    return re.sub(r"[\s·]+", "", kw).lower()


def aggregate(google, signal, nate):
    """소스별 순위를 점수화해 통합 순위 생성.
    상위일수록, 여러 소스에 겹칠수록 높은 점수."""
    score = defaultdict(float)
    display = {}
    hits = defaultdict(list)
    for src, items in (("google", google), ("signal", signal), ("nate", nate)):
        for i, it in enumerate(items):
            kw = it["keyword"] if isinstance(it, dict) else it
            key = normalize(kw)
            if not key:
                continue
            score[key] += (10 - i) if i < 10 else 1
            display.setdefault(key, kw)
            hits[key].append(src)
    ranked = sorted(score, key=lambda k: (-score[k], display[k]))
    return [
        {"keyword": display[k], "score": round(score[k], 1), "sources": hits[k]}
        for k in ranked
    ]


def collect():
    """세 소스를 모두 수집하고 통합 순위까지 계산해 dict로 반환.
    한 소스가 실패해도 나머지는 채운다."""
    result = {"google": [], "signal": [], "nate": [], "errors": {}}
    for name, fn in (("google", fetch_google), ("signal", fetch_signal), ("nate", fetch_nate)):
        try:
            result[name] = fn()
        except Exception as e:
            result["errors"][name] = str(e)
    result["combined"] = aggregate(result["google"], result["signal"], result["nate"])
    return result
