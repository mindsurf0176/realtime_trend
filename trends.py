#!/usr/bin/env python3
"""실시간 검색어 통합 조회기 (CLI).

세 소스를 한 번에 긁어서 통합 순위로 보여준다.
수집 로직은 sources.py 공용 모듈에 있다.

사용법:
  python3 trends.py            # 통합 + 소스별 표
  python3 trends.py --json     # JSON으로 출력 (자동화용)
  python3 trends.py --top 5    # 통합 순위 상위 N개만
"""
import argparse
import json
import sys

import sources


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="JSON으로 출력")
    ap.add_argument("--top", type=int, default=10, help="통합 순위 상위 N개")
    args = ap.parse_args()

    result = sources.collect()

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    print("=" * 44)
    print(" 실시간 검색어 통합")
    print("=" * 44)
    for row in result["combined"][: args.top]:
        srcs = ",".join(row["sources"])
        print(f"  {row['keyword']}  ({srcs})")

    print("\n[구글 트렌드]")
    for i, it in enumerate(result["google"][:10], 1):
        t = f"  {it['traffic']}" if it.get("traffic") else ""
        print(f"  {i}. {it['keyword']}{t}")

    print("\n[시그널 실검]")
    for it in result["signal"][:10]:
        print(f"  {it['rank']}. {it['keyword']}  [{it['state']}]")

    print("\n[네이트 이슈]")
    for i, kw in enumerate(result["nate"][:10], 1):
        print(f"  {i}. {kw}")

    if result["errors"]:
        print("\n(수집 실패: " + ", ".join(result["errors"]) + ")", file=sys.stderr)


if __name__ == "__main__":
    main()
