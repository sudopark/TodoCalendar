#!/usr/bin/env python3
"""en 대비 대상 언어 .strings의 키 세트·포맷 지정자 파리티 검증.

usage:
  scripts/check-localization-parity.py <lang> [<lang> ...]   # 지정 언어만
  scripts/check-localization-parity.py                       # 전 언어 (en 제외 자동 탐색)

en Localizable.strings에 키를 추가·삭제하면 나머지 전 언어 lproj를 함께 갱신해야 한다
(CLAUDE.md §1 짝 규칙). 이 스크립트가 그 짝을 기계 검증한다. 세부 번역 원칙은
.claude/rules/localization.md 참조.
"""
import re, sys, collections
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN_DIR = ROOT / "Supports/Extensions/Resources"
PAIRS = [
    "Supports/Extensions/Resources/{}.lproj/Localizable.strings",
    "TodoCalendarApp/AppExtensions/Widget/Resources/{}.lproj/Localizable.strings",
    "TodoCalendarApp/Resources/Localize/{}.lproj/InfoPlist.strings",
]
ENTRY = re.compile(r'"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
SPEC = re.compile(r'%(?:\d+\$)?[@dDuUxXoOfeEgGcsSaAF]|%(?:\d+\$)?l[du]')

def entries(path):
    text = Path(path).read_text(encoding="utf-8")
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    text = re.sub(r'//[^\n]*', '', text)
    found = ENTRY.findall(text)
    dup = [k for k, c in collections.Counter(k for k, _ in found).items() if c > 1]
    return dict(found), dup

def specs(value):
    return sorted(re.sub(r'\d+\$', '', m) for m in SPEC.findall(value))

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
    results = [check(lang) for lang in langs]
    sys.exit(0 if all(results) else 1)

if __name__ == "__main__":
    main(sys.argv[1:])
