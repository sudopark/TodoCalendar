#!/usr/bin/env python3
"""가이드 원고의 스크린샷 URL 을 언어별 이미지 경로로 바꾼다.

usage:
  scripts/rewrite-guide-image-lang.py <terms-repo-경로>            # dry-run
  scripts/rewrite-guide-image-lang.py <terms-repo-경로> --write    # 적용

`guide/images/calendar.png` (전 언어 공유) 를 `guide/images/<lang>/calendar.png` 로 옮기는
전환에 맞춰, 각 언어 md 의 절대 URL 을 그 언어 디렉토리로 가리키게 한다.

- **그 언어 이미지가 실제로 있을 때만** 바꾼다. md 는 정적이라 fallback 이 없어서,
  없는 경로를 가리키면 깨진 이미지가 그대로 노출된다. 촬영이 밀린 언어는 en 을 가리킨 채 남는다.
- 언어별로 찍지 않는 공유 자산(app-icon 등)은 `guide/images/` 루트에 그대로 두고 건드리지 않는다.
"""
import re, sys
from pathlib import Path

RAW_BASE = "https://raw.githubusercontent.com/sudopark/TodoCalendar-Terms/main/guide/images"
SHARED = {"app-icon.png"}
SRC = re.compile(rf'({re.escape(RAW_BASE)}/)((?:[\w-]+/)?)([\w.-]+\.png)')


def rewrite(guide_dir, lang, write):
    changes = []
    for md in sorted((guide_dir / lang).glob("*.md")):
        text = md.read_text(encoding="utf-8")

        def replace(match):
            prefix, _current_dir, name = match.groups()
            if name in SHARED:
                return f"{prefix}{name}"
            if not (guide_dir / "images" / lang / name).exists():
                return match.group(0)
            return f"{prefix}{lang}/{name}"

        updated = SRC.sub(replace, text)
        if updated == text:
            continue
        changed = sum(1 for a, b in zip(SRC.findall(text), SRC.findall(updated)) if a != b)
        changes.append((md, changed))
        if write:
            md.write_text(updated, encoding="utf-8")
    return changes


def main(args):
    if not args:
        print(__doc__)
        return 1
    guide_dir = Path(args[0]).expanduser().resolve() / "guide"
    write = "--write" in args[1:]
    if not guide_dir.is_dir():
        print(f"guide 디렉토리를 찾을 수 없다: {guide_dir}")
        return 1

    langs = sorted(p.name for p in guide_dir.iterdir() if p.is_dir() and p.name != "images")
    total = 0
    for lang in langs:
        changes = rewrite(guide_dir, lang, write)
        for md, count in changes:
            print(f"[{lang}] {md.relative_to(guide_dir.parent)}: {count} URL")
            total += count
    print(f"{'적용' if write else 'dry-run'} — {total} URL")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
