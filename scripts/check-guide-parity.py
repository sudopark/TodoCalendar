#!/usr/bin/env python3
"""서비스 이용 가이드(sudopark/TodoCalendar-Terms `guide/`)의 en 대비 구조 파리티 검증.

usage:
  scripts/check-guide-parity.py <terms-repo-경로> <lang> [<lang> ...]   # 지정 언어만
  scripts/check-guide-parity.py <terms-repo-경로>                       # 전 언어 (en 제외 자동 탐색)

가이드 원고는 이 레포가 아니라 약관 레포(`sudopark/TodoCalendar-Terms`)의 `guide/<언어코드>/` 에
있고, 언어 코드는 lproj 와 같다. 앱이 인웹뷰로 여는 페이지라 문구는 각 언어 lproj 값을 인용하므로
가이드 번역은 lproj 번역의 후행 작업이고, 검증 도구도 여기 둔다.

번역문의 어학 품질이 아니라 **en 과 어긋나면 문서가 깨지는 것**만 본다:
파일 세트, 링크 대상 파일, 이미지 URL, 헤딩 레벨 시퀀스, 그리고 죽은 앵커.

헤딩 앵커(`./01-basics.md#foremost-event`)는 그 언어의 헤딩 텍스트를 따라가므로 en 과 같을 수
없다 — 링크 대상 파일은 en 과 일치하는지, 앵커는 같은 언어의 대상 문서에 실제로 존재하는
헤딩인지를 따로 본다.
"""
import re, sys, unicodedata
from pathlib import Path

LINK = re.compile(r'\]\((\./[^)]+)\)')
IMG = re.compile(r'https://raw\.githubusercontent\.com/[^\s")]+')
HEADING = re.compile(r'^(#{1,6})\s+(.+?)\s*$', re.M)

def slug(text):
    """GitHub 헤딩 앵커 규칙 — 마크다운 강조를 걷어내고 문자(L)·조합부호(M)·숫자(N)만 남긴다.
    조합부호를 빼면 태국어·힌디의 모음/성조 부호가 지워져 멀쩡한 앵커가 죽은 링크로 잡힌다."""
    t = re.sub(r'\[([^\]]*)\]\([^)]*\)', r'\1', text)
    t = t.replace('*', '').replace('`', '').strip().lower()
    t = ''.join(c for c in t if c in ' -_' or unicodedata.category(c)[0] in 'LMN')
    return re.sub(r'\s+', '-', t)

def anchors_of(headings):
    """문서 안에 같은 텍스트의 헤딩이 둘 이상이면 github-slugger 처럼 둘째부터 -1, -2 를 붙인다.
    가이드는 Google 절·Apple 절에 같은 이름의 헤딩을 두므로 이 구분이 없으면 앵커가 뭉개진다."""
    seen, anchors = {}, set()
    for _, text in headings:
        base = slug(text)
        count = seen.get(base, 0)
        anchors.add(base if count == 0 else f"{base}-{count}")
        seen[base] = count + 1
    return anchors

def parse(path):
    text = Path(path).read_text(encoding="utf-8")
    headings = [(len(hashes), title) for hashes, title in HEADING.findall(text)]
    return {
        "links": LINK.findall(text),
        "images": sorted(image_name(url) for url in IMG.findall(text)),
        "levels": [level for level, _ in headings],
        "anchors": anchors_of(headings),
    }

def image_name(url):
    """스크린샷은 언어별로 `images/<lang>/` 아래 갈리므로 언어 세그먼트를 걷어내고 파일명만 본다 —
    아직 촬영 안 된 언어는 en 이 있는 루트를 계속 가리켜서 URL 자체는 일치하지 않는다."""
    return url.rsplit('/', 1)[-1]


def guide_files(guide_dir):
    """검사 대상 파일 세트는 en 디렉토리가 정본 — 원고에 문서가 늘어도 이 스크립트를 고칠 필요가 없다."""
    names = [p.name for p in (guide_dir / "en").glob("*.md")]
    return sorted(names, key=lambda name: (name != "README.md", name))

def check(guide_dir, files, lang):
    docs, ok = {}, True
    for name in files:
        path = guide_dir / lang / name
        if not path.exists():
            print(f"[{lang}] MISSING FILE: guide/{lang}/{name}")
            ok = False
            continue
        docs[name] = parse(path)
    if not ok:
        return False
    for name in files:
        en, xx, file_ok = parse(guide_dir / "en" / name), docs[name], True
        en_targets = sorted(link.split('#')[0] for link in en["links"])
        xx_targets = sorted(link.split('#')[0] for link in xx["links"])
        if en_targets != xx_targets:
            print(f"[{lang}] {name} link target mismatch: en={en_targets} {lang}={xx_targets}")
            file_ok = False
        if en["images"] != xx["images"]:
            print(f"[{lang}] {name} image set mismatch: only-en={sorted(set(en['images'])-set(xx['images']))} only-{lang}={sorted(set(xx['images'])-set(en['images']))}")
            file_ok = False
        if en["levels"] != xx["levels"]:
            print(f"[{lang}] {name} heading level sequence: en={en['levels']} {lang}={xx['levels']}")
            file_ok = False
        for link in xx["links"]:
            target, _, anchor = link.partition('#')
            if not anchor:
                continue
            target_doc = docs.get(target.removeprefix('./'))
            if target_doc is None:
                print(f"[{lang}] {name} anchor points at unknown file: {link}")
                file_ok = False
            elif anchor not in target_doc["anchors"]:
                print(f"[{lang}] {name} dead anchor {link} — {target} 에 그 헤딩이 없다")
                file_ok = False
        if file_ok:
            print(f"[{lang}] {name}: OK (links={len(xx['links'])}, images={len(xx['images'])}, headings={len(xx['levels'])})")
        ok = ok and file_ok
    return ok

def main(args):
    if not args:
        print(__doc__.split("\n\n")[1])
        sys.exit(2)
    guide_dir = Path(args[0]).expanduser() / "guide"
    if not (guide_dir / "en").is_dir():
        print(f"en 가이드 디렉토리를 찾을 수 없다: {guide_dir / 'en'}")
        sys.exit(2)
    files = guide_files(guide_dir)
    if not files:
        print(f"검사할 md 파일이 없다: {guide_dir / 'en'}")
        sys.exit(2)
    langs = args[1:] or sorted(
        p.name for p in guide_dir.iterdir() if p.is_dir() and p.name not in ("en", "images")
    )
    sys.exit(0 if all([check(guide_dir, files, lang) for lang in langs]) else 1)

if __name__ == "__main__":
    main(sys.argv[1:])
