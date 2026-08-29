#!/usr/bin/env python3
"""에이전트 발동형 레코드 기록기 — skill_end(준수 자가 기록)·correction(유저 교정)·improvement(정비 마킹)·axis_leak(채점 축 누수).

훅이 아니라 에이전트가 CLI로 직접 호출한다 (CLAUDE.md §1 공통 조항, #690).
사용법 오류는 exit 2 (호출자가 재시도), 그 외 오류는 fail-open exit 0.
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone

LOG_DIR = os.environ.get("USAGE_LOG_DIR") or os.path.expanduser("~/.claude/usage-log")

PARTIAL_GATE = """partial 판정 재확인 — 아래 이탈이 정말 '조항이 허용하지 않은 이탈'인가?

조항이 조건부 생략·갈음·대체 경로를 규정하고 그 조건을 충족해 그 경로를 탔으면 full이다.
규정된 선택지를 고른 것은 이행이지 이탈이 아니다.
판정은 규범 판단이 아니라 "그 조항이 이 생략을 문언으로 규정하고 있나"라는 사실 확인이다.

기록하려는 이탈:
{deviations}

→ 재판정 결과 full이면  --compliance full 로 다시 호출
→ 진짜 이탈이면        --deviation-reviewed 를 붙여 다시 호출"""


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def append_record(record):
    os.makedirs(LOG_DIR, exist_ok=True)
    path = os.path.join(LOG_DIR, datetime.now().strftime("%Y-%m-%d") + ".jsonl")
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")


def usage_error(message):
    print(f"log-record: {message}", file=sys.stderr)
    sys.exit(2)


def parse_deviations(raw_list):
    deviations = []
    for raw in raw_list:
        clause, _, reason = raw.partition("::")
        deviations.append({"clause": clause.strip(), "reason": reason.strip()})
    return deviations


def build_record(args):
    record = {
        "ts": now_iso(),
        "event": args.event,
        "session_id": args.session or os.environ.get("CLAUDE_CODE_SESSION_ID", ""),
        "cwd": os.getcwd(),
    }
    if args.event == "skill_end":
        if not args.name or not args.compliance:
            usage_error("skill_end엔 --name·--compliance 필수")
        deviations = parse_deviations(args.deviation)
        if args.compliance == "partial":
            if not deviations:
                usage_error("partial엔 --deviation '조항::사유' 필수")
            if not args.deviation_reviewed:
                listed = "\n".join(f"  - {d['clause']} :: {d['reason']}" for d in deviations)
                usage_error(PARTIAL_GATE.format(deviations=listed))
        record.update({"name": args.name, "compliance": args.compliance, "deviations": deviations})
    elif args.event == "correction":
        if not args.summary:
            usage_error("correction엔 --summary 필수")
        skills = [s.strip() for s in args.skills.split(",") if s.strip()]
        record.update({"skills": skills, "summary": args.summary, "gist": args.gist or ""})
    elif args.event == "improvement":
        if not args.name:
            usage_error("improvement엔 --name 필수")
        record["name"] = args.name
    else:  # axis_leak
        if args.missed_axis is None or not args.finding:
            usage_error("axis_leak엔 --missed-axis·--finding 필수")
        record.update({"missed_axis": args.missed_axis, "finding": args.finding, "pr": args.pr or ""})
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("event", choices=["skill_end", "correction", "improvement", "axis_leak"])
    parser.add_argument("--name", help="대상 스킬명 (skill_end·improvement)")
    parser.add_argument("--compliance", choices=["full", "partial"])
    parser.add_argument("--deviation", action="append", default=[], help="'조항::사유' 형식, 반복 가능")
    parser.add_argument("--deviation-reviewed", action="store_true",
                        help="partial 게이트 통과 표식 — 조항이 허용하지 않은 이탈임을 재확인한 뒤에만 붙인다")
    parser.add_argument("--skills", default="", help="쉼표 구분 귀속 스킬 (correction)")
    parser.add_argument("--summary", help="교정 요지 (correction)")
    parser.add_argument("--gist", help="유저 발화 요지 (correction)")
    parser.add_argument("--missed-axis", type=int, choices=[1, 2, 3], help="놓쳤어야 할 채점 축 (axis_leak)")
    parser.add_argument("--finding", help="누수 한 줄 요약 (axis_leak)")
    parser.add_argument("--pr", help="관련 PR 번호 (axis_leak, 생략 가능)")
    parser.add_argument("--session", help="session_id override — 생략 시 CLAUDE_CODE_SESSION_ID env")
    args = parser.parse_args()
    append_record(build_record(args))


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        sys.exit(0)
