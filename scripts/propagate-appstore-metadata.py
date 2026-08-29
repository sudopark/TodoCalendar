#!/usr/bin/env python3
"""`deliver init` 이 내려받은 en-US 비번역 필드를 나머지 App Store 로케일로 전파.

usage:
  scripts/propagate-appstore-metadata.py            # 계획만 출력, 파일은 안 건드림
  scripts/propagate-appstore-metadata.py --apply    # 실제 복사
  scripts/propagate-appstore-metadata.py --metadata <경로>

`deliver init` 은 ASC 에 **이미 활성화된** 로케일(en-US·ko)의 값만 내려받는다. 이번에 새로 올리는
나머지 로케일은 ASC 에 없던 로케일이라 `name`·`support_url`·`privacy_url` 이 빈 채로 남고, 셋 다
ASC 심사 필수라 그대로 업로드하면 제출이 막힌다.

그 필드들은 번역 대상이 아니라 전 로케일이 같은 값을 쓰는 자리다:
- `name` — 앱 이름. 기기 표시명도 로케일 오버라이드가 없다 (`TodoCalendarApp/Project.swift` 의
  CFBundleDisplayName 하나뿐, 어느 `InfoPlist.strings` 에도 재정의 없음)
- `support_url`·`marketing_url` — 같은 사이트를 가리킨다
- `privacy_url` — 앱이 `LegalLink` 에서 ko / en 두 갈래로만 가른다. ko 는 `deliver init` 이
  자기 값을 받아오므로 여기서 덮지 않는다

그래서 하는 일은 값을 새로 정하는 게 아니라 en-US 값을 복사하는 것뿐이다.
**이미 있는 파일은 절대 덮어쓰지 않는다** — ko 값과 로케일별 번역 원고를 지키는 게 조건이다.
"""
import argparse
import sys
from pathlib import Path

# deliver 가 로케일 디렉토리에서 읽는 필드 중 번역 대상이 아닌 것
# (번역 대상: subtitle·description·keywords·promotional_text·release_notes)
# apple_tv_privacy_policy 는 tvOS 전용이라 제외한다
PROPAGATED_FIELDS = ["name", "support_url", "marketing_url", "privacy_url"]

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
    parser.add_argument("--apply", action="store_true", help="실제로 복사한다 (기본은 계획만 출력)")
    args = parser.parse_args()

    root: Path = args.metadata
    source = root / SOURCE_LOCALE
    if not source.is_dir():
        print(f"[중단] {source} 가 없다. --metadata 경로를 확인해라.")
        return 1

    available = {}
    for field in PROPAGATED_FIELDS:
        path = source / f"{field}.txt"
        if not path.exists():
            print(f"[건너뜀] {SOURCE_LOCALE}/{field}.txt 없음 — `deliver init` 을 먼저 돌려라")
            continue
        text = path.read_text(encoding="utf-8")
        if not text.strip():
            print(f"[건너뜀] {SOURCE_LOCALE}/{field}.txt 가 비었다 — ASC 에도 값이 없다")
            continue
        available[field] = text

    if not available:
        print("전파할 필드가 없다.")
        return 1

    targets = [d for d in locale_dirs(root) if d.name != SOURCE_LOCALE]
    planned, kept = [], []
    for target in targets:
        for field, text in available.items():
            path = target / f"{field}.txt"
            if path.exists():
                kept.append(f"{target.name}/{field}.txt")
                continue
            planned.append((path, text))

    for path, text in planned:
        rel = path.relative_to(root)
        print(f"{'복사' if args.apply else '복사 예정'}  {rel}")
        if args.apply:
            path.write_text(text, encoding="utf-8")

    print()
    print(f"로케일 {len(targets)}개 · 필드 {', '.join(available)}")
    print(f"새로 채움 {len(planned)}개 · 이미 있어 보존 {len(kept)}개")
    if kept:
        shown = ", ".join(kept[:8])
        rest = f" 외 {len(kept) - 8}개" if len(kept) > 8 else ""
        print(f"보존: {shown}{rest}")
    if not args.apply and planned:
        print("\n계획만 출력했다. 실제로 쓰려면 --apply 를 붙여라.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
