#!/usr/bin/env python3
"""스킬별 usage-log 집계·임계 판정 — 초과 항목만 정비 권고로 출력한다 (#690).

- improvement 마킹 이벤트의 최대 ts 이후 레코드만 집계 (정비 반영분은 신호에서 소비 처리).
  ts는 ISO8601 문자열 사전순 비교 — 타임존 혼재 시 근사치.
- 발동/종료는 세션 단위 dedupe (#712) — 세션 재개·SDD로 같은 세션에서 재발동해도 1회로 센다.
  session_id 없는 레코드는 레코드별로 따로 센다.
- (미귀속) 버킷은 --all 진단 표에만 노출 — 스킬이 아니라 정비(improvement 마킹) 소비 경로가 없어 임계 판정에서 제외.
- axis_leak 이벤트는 missed_axis(1/2/3)별로 별도 집계하며, improvement name이 합성 버킷 "axis:<n>" 형식이면 그 ts 이후만 신선 처리(소비 마킹) — 스킬 stats와 섞지 않는다.
- exit 0 고정: 게이트가 아니라 제안이다. 임계는 usage-thresholds.json.
"""
import argparse
import glob
import json
import os

LOG_DIR = os.environ.get("USAGE_LOG_DIR") or os.path.expanduser("~/.claude/usage-log")
CONFIG_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "usage-thresholds.json")
UNATTRIBUTED = "(미귀속)"


def load_records():
    records = []
    for path in sorted(glob.glob(os.path.join(LOG_DIR, "*.jsonl"))):
        try:
            with open(path, encoding="utf-8") as f:
                for line in f:
                    try:
                        records.append(json.loads(line))
                    except ValueError:
                        continue
        except OSError:
            continue
    return records


def improvement_marks(records):
    marks = {}
    for record in records:
        if record.get("event") != "improvement" or not record.get("name"):
            continue
        name = record["name"]
        marks[name] = max(marks.get(name, ""), record.get("ts", ""))
    return marks


def aggregate(records):
    marks = improvement_marks(records)
    stats = {}
    axis_stats = {1: 0, 2: 0, 3: 0}

    invocation_sessions = {}
    end_sessions = {}

    def stat(name):
        return stats.setdefault(name, {"invocations": 0, "ends": 0, "full": 0, "partial": 0, "corrections": 0})

    def is_fresh(name, record):
        return record.get("ts", "") > marks.get(name, "")

    def is_first_in_session(seen, name, record, index):
        key = record.get("session_id") or f"record:{index}"
        bucket = seen.setdefault(name, set())
        if key in bucket:
            return False
        bucket.add(key)
        return True

    for index, record in enumerate(records):
        event = record.get("event")
        if event == "skill":
            name = record.get("name", "")
            if name and is_fresh(name, record) and is_first_in_session(invocation_sessions, name, record, index):
                stat(name)["invocations"] += 1
        elif event == "skill_end":
            name = record.get("name", "")
            if name and is_fresh(name, record) and is_first_in_session(end_sessions, name, record, index):
                entry = stat(name)
                entry["ends"] += 1
                entry["partial" if record.get("compliance") == "partial" else "full"] += 1
        elif event == "correction":
            for name in record.get("skills") or [UNATTRIBUTED]:
                if is_fresh(name, record):
                    stat(name)["corrections"] += 1
        elif event == "axis_leak":
            axis = record.get("missed_axis")
            if axis in (1, 2, 3) and is_fresh(f"axis:{axis}", record):
                axis_stats[axis] += 1
    return stats, axis_stats


def missing_rate(entry):
    if entry["invocations"] == 0:
        return 0.0
    return max(0.0, 1.0 - entry["ends"] / entry["invocations"])


def violations(stats, axis_stats, thresholds):
    lines = []
    for name, entry in sorted(stats.items()):
        if name == UNATTRIBUTED:
            continue
        if entry["corrections"] >= thresholds["correction_count"]:
            lines.append(f"⚠️ {name} — correction {entry['corrections']}건 (임계 {thresholds['correction_count']})")
        if entry["partial"] >= thresholds["partial_count"]:
            lines.append(f"⚠️ {name} — 준수 partial {entry['partial']}건 (임계 {thresholds['partial_count']})")
        if entry["invocations"] >= thresholds["min_invocations_for_missing"]:
            rate = missing_rate(entry)
            if rate >= thresholds["missing_rate"]:
                lines.append(
                    f"⚠️ {name} — 종료 레코드 누락률 {rate:.0%} "
                    f"(발동 {entry['invocations']}·종료 {entry['ends']}, 임계 {thresholds['missing_rate']:.0%})"
                )
    for axis in (1, 2, 3):
        count = axis_stats[axis]
        if count >= thresholds["axis_leak_count"]:
            lines.append(
                f"⚠️ 축{axis} 누수 {count}건 (임계 {thresholds['axis_leak_count']}) — "
                f"implement 스킬 축{axis} 관문 정비 검토 (소비 마킹 버킷 axis:{axis})"
            )
    return lines


def full_table(stats, axis_stats):
    header = f"{'스킬':<24} {'발동':>4} {'종료':>4} {'full':>5} {'partial':>7} {'correction':>10}"
    lines = [header]
    for name, entry in sorted(stats.items()):
        lines.append(
            f"{name:<24} {entry['invocations']:>4} {entry['ends']:>4} "
            f"{entry['full']:>5} {entry['partial']:>7} {entry['corrections']:>10}"
        )
    if any(axis_stats.values()):
        lines.append(f"축별 누수 — 축1 {axis_stats[1]} · 축2 {axis_stats[2]} · 축3 {axis_stats[3]}")
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="임계와 무관하게 스킬별 전체 집계 표 출력")
    args = parser.parse_args()

    with open(CONFIG_PATH, encoding="utf-8") as f:
        thresholds = json.load(f)

    stats, axis_stats = aggregate(load_records())
    lines = full_table(stats, axis_stats) if args.all else violations(stats, axis_stats, thresholds)
    if lines:
        print("\n".join(lines))


if __name__ == "__main__":
    main()
