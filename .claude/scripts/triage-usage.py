#!/usr/bin/env python3
"""임계 초과 신호를 오탐/중복/실제로 판정한다 — 보고 가치 있는 것만 남긴다 (#951).

aggregate-usage.py 는 "임계를 넘었다"까지만 말한다. 그 다음 판단(이미 정비된 신호인가,
이미 이슈에 적힌 신호인가)을 매번 추론으로 하면 세션마다 결론이 튄다. 그 판정을 여기로 옮긴다.

판정 셋:
- duplicate — 누적 이슈에 이미 적힌 신호(`<!-- signal: <bucket>/<kind> -->`). 재보고하지 않는다.
- stale — 기여 레코드가 전부 대상 스킬 파일의 마지막 커밋보다 과거다. 정비가 이미 들어갔고
  소비 마킹만 안 된 상태 → 보고 대상이 아니라 상태 정리 대상이다.
- actionable — 그 외. 기여 레코드 전문과 함께 보고한다.

stale 판정에 파일 mtime을 쓰지 않는다 — 체크아웃 시각이라 정비 시점을 나타내지 못한다.

stale이 성립하지 않아 항상 actionable로 남는 셋이 있다. 판정 누락이 아니라 구조다:
- 개정 이력이 없는 대상 — 플러그인 스킬처럼 조항이 이 레포 밖이라 개정 시각을 볼 수 없다.
- `missing_rate` — 발동/종료 카운트에서 파생된 비율이라 대응하는 개별 레코드가 없다. 비교할
  기여 레코드가 없으니 소비는 `improvement --name <스킬>` 수동 마킹으로만 된다.
- `axis:<n>` — 축 누수는 프로덕트 코드에서 나온 finding이고 버킷과 조항 소유 스킬(implement)이
  일치하지 않는다. implement를 무슨 이유로 고치든 모든 축 누수가 stale로 뒤집혀 진짜 신호가
  조용히 소비된다. 축 소비도 `improvement --name axis:<n>` 수동 마킹으로만 한다.
"""
import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True  # aggregate-usage.py 를 exec 할 때 레포에 __pycache__ 를 남기지 않는다

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SKILLS_ROOT = os.path.join(os.path.dirname(SCRIPT_DIR), "skills")
CONFIG_PATH = os.path.join(SCRIPT_DIR, "usage-thresholds.json")
SIGNAL_MARKER = re.compile(r"<!--\s*signal:\s*([^\s>]+)\s*-->")
AXIS_OWNER = "implement"


def load_aggregate_module():
    spec = importlib.util.spec_from_file_location(
        "aggregate_usage", os.path.join(SCRIPT_DIR, "aggregate-usage.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def owning_skill(bucket):
    """신호 버킷 → 조항을 담은 스킬 디렉토리명. 정비 대상이 이 레포 밖이면 None."""
    if bucket.startswith("axis:"):
        return AXIS_OWNER
    if ":" in bucket:
        return None
    return bucket


def last_revision(skills_root, bucket):
    skill = owning_skill(bucket)
    if not skill or skill != bucket:
        return None
    relative = os.path.join(skill, "SKILL.md")
    if not os.path.exists(os.path.join(skills_root, relative)):
        return None
    try:
        result = subprocess.run(
            ["git", "-C", skills_root, "log", "-1", "--format=%cI", "--", relative],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout.strip() or None


def recorded_signals(path):
    if not path:
        return set()
    try:
        with open(path, encoding="utf-8") as f:
            return set(SIGNAL_MARKER.findall(f.read()))
    except OSError:
        return set()


def triage(violations, contributors, skills_root, recorded):
    items = []
    for violation in violations:
        bucket, kind = violation["bucket"], violation["kind"]
        records = contributors.get((bucket, kind), [])
        newest = max((r.get("ts", "") for r in records), default="")
        revision = last_revision(skills_root, bucket)

        if f"{bucket}/{kind}" in recorded:
            verdict = "duplicate"
        elif revision and newest and revision > newest:
            verdict = "stale"
        else:
            verdict = "actionable"

        items.append({
            **violation,
            "signal": f"{bucket}/{kind}",
            "verdict": verdict,
            "last_revision": revision,
            "newest_record": newest,
            "records": records,
        })
    return items


def record_gist(record):
    """레코드 종류별 요지 — 이벤트마다 요지를 담는 필드가 다르다.

    correction은 summary, axis_leak은 finding, skill_end(partial)은 deviations다.
    폴백이 빠지면 그 종류의 신호가 ts만 찍혀 "요지와 함께 보고한다"는 규약이 지켜지지 않는다.
    """
    direct = record.get("summary") or record.get("finding")
    if direct:
        return direct
    deviations = record.get("deviations") or []
    return "; ".join(f"{d.get('clause', '')}::{d.get('reason', '')}" for d in deviations)


def render(items):
    lines = []
    actionable = [item for item in items if item["verdict"] == "actionable"]
    stale = [item for item in items if item["verdict"] == "stale"]

    for item in actionable:
        lines.append(item["message"])
        lines.append(f"    signal: {item['signal']}")
        for record in item["records"]:
            lines.append(f"    · {record.get('ts', '')} {record_gist(record)}")

    if stale:
        lines.append("")
        lines.append("정비가 이미 반영된 신호 — 상태 정리만 하면 된다 (보고 대상 아님):")
        for item in stale:
            lines.append(
                f"    python3 .claude/hooks/log-record.py improvement --name {item['bucket']}"
                f"    # {item['signal']} (마지막 개정 {item['last_revision']})"
            )
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="판정 결과를 JSON으로 출력")
    parser.add_argument("--skills-root", default=DEFAULT_SKILLS_ROOT, help="스킬 디렉토리 루트")
    parser.add_argument("--recorded-file", help="누적 이슈 본문 파일 — signal 마커를 중복 판정에 쓴다")
    args = parser.parse_args()

    aggregate_usage = load_aggregate_module()
    with open(CONFIG_PATH, encoding="utf-8") as f:
        thresholds = json.load(f)

    stats, axis_stats, contributors = aggregate_usage.aggregate(aggregate_usage.load_records())
    violations = aggregate_usage.violation_records(stats, axis_stats, thresholds)
    items = triage(violations, contributors, args.skills_root, recorded_signals(args.recorded_file))

    if args.json:
        print(json.dumps(items, ensure_ascii=False, indent=2))
        return
    lines = render(items)
    if lines:
        print("\n".join(lines))


if __name__ == "__main__":
    main()
