#!/usr/bin/env python3
"""en 대비 대상 언어 .strings의 키 세트·포맷 지정자 파리티 검증.

usage:
  scripts/check-localization-parity.py <lang> [<lang> ...]   # 지정 언어만
  scripts/check-localization-parity.py                       # 전 언어 (en 제외 자동 탐색)

개발 중엔 en/ko만 갱신하고 나머지 29개 언어 번역은 트래킹 이슈 #810으로 미룬다
(CLAUDE.md §1). 그래서 용도가 둘이다:
  - 작업 커밋 전: `... ko` 로 en↔ko 파리티만 검증.
  - #810 일괄 번역 시: 인자 없이 실행해 나온 missing keys 가 곧 번역 대기 키 목록이고,
    전 언어 0 위반이 close 조건.
세부 번역 원칙은 .claude/rules/localization.md 참조.
"""
import re, sys, collections
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN_DIR = ROOT / "Supports/Extensions/Resources"
PAIRS = [
    "Supports/Extensions/Resources/{}.lproj/Localizable.strings",
    "TodoCalendarApp/AppExtensions/Widget/Resources/{}.lproj/Localizable.strings",
    "TodoCalendarApp/Resources/Localize/{}.lproj/InfoPlist.strings",
    "TodoCalendarApp/Resources/Localize/{}.lproj/Localizable.strings",
    "TodoCalendarApp/Resources/Localize/{}.lproj/AppShortcuts.strings",
]
ENTRY = re.compile(r'"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
SPEC = re.compile(r'%(?:\d+\$)?[-#0+ ]*\d*(?:\.\d+)?(?:hh?|ll?|q|z|t|L)?[@dDuUxXoOfeEgGcsSaAF]')

def entries(path):
    text = Path(path).read_text(encoding="utf-8")
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = re.sub(r'^\s*//[^\n]*', '', text, flags=re.M)
    found = ENTRY.findall(text)
    dup = [k for k, c in collections.Counter(k for k, _ in found).items() if c > 1]
    return dict(found), dup

def specs(value):
    return sorted(re.sub(r'\d+\$', '', m) for m in SPEC.findall(value))

def check_en():
    ok = True
    for tpl in PAIRS:
        _, dup = entries(ROOT / tpl.format("en"))
        if dup:
            print(f"[en] {tpl.format('en')} duplicate keys: {dup[:10]}")
            ok = False
    return ok

def check(lang):
    ok = True
    for tpl in PAIRS:
        file_ok = True
        en, _ = entries(ROOT / tpl.format("en"))
        xx_path = ROOT / tpl.format(lang)
        try:
            xx, xx_dup = entries(xx_path)
        except FileNotFoundError:
            print(f"[{lang}] MISSING FILE: {xx_path}")
            ok = False
            continue
        missing = sorted(set(en) - set(xx))
        extra = sorted(set(xx) - set(en))
        spec_bad = sorted(k for k in set(en) & set(xx) if specs(en[k]) != specs(xx[k]))
        rel = tpl.format(lang)
        if missing: print(f"[{lang}] {rel} missing keys: {missing[:10]}{'...' if len(missing) > 10 else ''}"); file_ok = False
        if extra: print(f"[{lang}] {rel} extra keys: {extra[:10]}"); file_ok = False
        if xx_dup: print(f"[{lang}] {rel} duplicate keys: {xx_dup[:10]}"); file_ok = False
        if spec_bad: print(f"[{lang}] {rel} format-spec mismatch: {spec_bad[:10]}"); file_ok = False
        if file_ok: print(f"[{lang}] {rel}: OK (keys={len(xx)}, format-specs match)")
        ok = ok and file_ok
    return ok

def main(args):
    langs = args or sorted(
        p.name.removesuffix(".lproj") for p in MAIN_DIR.glob("*.lproj") if p.name != "en.lproj"
    )
    results = [check_en()] + [check(lang) for lang in langs]
    sys.exit(0 if all(results) else 1)

if __name__ == "__main__":
    main(sys.argv[1:])
