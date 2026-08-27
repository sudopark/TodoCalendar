#!/usr/bin/env python3
"""`fastlane/metadata/<로케일>/release_notes.txt` 가 업로드 가능한 상태인지 검사.

usage:
  scripts/check-release-notes.py                      # 전 로케일 검사
  scripts/check-release-notes.py --metadata <경로>

release-notes 스킬 §4 의 업로드 직전 게이트다. 위반이 하나라도 있으면 종료코드 1.

deliver 는 파일이 없는 필드를 조용히 건너뛴다 — 그래서 번역이 덜 된 채로 올려도 업로드 자체는
성공하고, ASC 에서 그 로케일만 이전 버전 노트가 남거나 심사 제출이 막힌다. 로컬에서 먼저 잡는다.
"""
import argparse
import sys
from pathlib import Path

FIELD = "release_notes"

# ASC 의 "이번 버전의 새로운 기능" 필드 상한
MAX_CHARACTERS = 4000

SOURCE_LOCALE = "en-US"

# deliver 가 로케일이 아닌 용도로 쓰는 하위 디렉토리
NON_LOCALE_DIRS = {
    "review_information",
    "trade_representative_contact_information",
    "app_clip_review_information",
}


def locale_dirs(root: Path) -> list[Path]:
    return sorted(
        d for d in root.iterdir()
        if d.is_dir() and d.name not in NON_LOCALE_DIRS
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata", default="fastlane/metadata", type=Path)
    args = parser.parse_args()

    root: Path = args.metadata
    if not root.is_dir():
        print(f"[중단] {root} 가 없다. --metadata 경로를 확인해라.")
        return 1

    targets = locale_dirs(root)
    if not targets:
        print(f"[중단] {root} 에 로케일 디렉토리가 없다.")
        return 1

    notes: dict[str, str] = {}
    violations: list[str] = []

    for target in targets:
        path = target / f"{FIELD}.txt"
        if not path.exists():
            violations.append(f"{target.name} — {FIELD}.txt 없음")
            continue
        # 길이 판정과 중복 판정이 같은 문자열을 보게 정규화를 한 번만 한다
        text = path.read_text(encoding="utf-8").strip()
        if not text:
            violations.append(f"{target.name} — 비어 있음")
            continue
        length = len(text)
        if length > MAX_CHARACTERS:
            violations.append(
                f"{target.name} — {length}자로 상한 {MAX_CHARACTERS}자를 넘음 ({length - MAX_CHARACTERS}자 초과)"
            )
            continue
        notes[target.name] = text

    source = notes.get(SOURCE_LOCALE)
    if source is None:
        # en-US 가 탈락하면 비교 기준이 없어 나머지 로케일의 복사본이 이번 회차엔 안 드러난다
        print(f"[건너뜀] {SOURCE_LOCALE} 가 위에서 걸려 번역 누락 검사를 못 했다 — 고친 뒤 다시 돌려라")
    else:
        for locale, text in sorted(notes.items()):
            if locale != SOURCE_LOCALE and text == source:
                violations.append(f"{locale} — {SOURCE_LOCALE} 원문과 글자까지 같다 (번역이 안 된 복사본)")

    for line in violations:
        print(f"[위반] {line}")

    print()
    print(f"로케일 {len(targets)}개 · 통과 {len(notes)}개 · 위반 {len(violations)}개")
    if violations:
        print("업로드하지 마라 — 위 로케일을 채운 뒤 다시 돌려라.")
        return 1
    print(f"전부 통과. 최장 {max(len(t) for t in notes.values())}자 / 상한 {MAX_CHARACTERS}자.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
