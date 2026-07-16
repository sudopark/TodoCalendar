#!/usr/bin/env python3
"""에이전트 발동형 레코드 기록기 — skill_end(준수 자가 기록)·correction(유저 교정)·improvement(정비 마킹).

훅이 아니라 에이전트가 CLI로 직접 호출한다 (CLAUDE.md §1 공통 조항, #690).
사용법 오류는 exit 2 (호출자가 재시도), 그 외 오류는 fail-open exit 0.
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone

LOG_DIR = os.environ.get("USAGE_LOG_DIR") or os.path.expanduser("~/.claude/usage-log")


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
        if args.compliance == "partial" and not deviations:
            usage_error("partial엔 --deviation '조항::사유' 필수")
        record.update({"name": args.name, "compliance": args.compliance, "deviations": deviations})
    elif args.event == "correction":
        if not args.summary:
            usage_error("correction엔 --summary 필수")
        skills = [s.strip() for s in args.skills.split(",") if s.strip()]
        record.update({"skills": skills, "summary": args.summary, "gist": args.gist or ""})
    else:  # improvement
        if not args.name:
            usage_error("improvement엔 --name 필수")
        record["name"] = args.name
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("event", choices=["skill_end", "correction", "improvement"])
    parser.add_argument("--name", help="대상 스킬명 (skill_end·improvement)")
    parser.add_argument("--compliance", choices=["full", "partial"])
    parser.add_argument("--deviation", action="append", default=[], help="'조항::사유' 형식, 반복 가능")
    parser.add_argument("--skills", default="", help="쉼표 구분 귀속 스킬 (correction)")
    parser.add_argument("--summary", help="교정 요지 (correction)")
    parser.add_argument("--gist", help="유저 발화 요지 (correction)")
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
