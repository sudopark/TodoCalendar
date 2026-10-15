#!/usr/bin/env python3
"""촬영한 화면 원본을 App Store 업로드용 마케팅 스샷으로 합성한다.

usage:
    python3 scripts/compose-appstore-screenshots.py <lang> [<lang> ...]
    python3 scripts/compose-appstore-screenshots.py --all

입력: snapshot-appstore/<lang>/<NN-슬러그>.png + snapshot-appstore/<lang>/captions/<NN-슬러그>.png
      05-widgets 만 화면 원본이 없다 — snapshot-appstore/<lang>/widgets/ 의 위젯 원본을 홈화면으로 합성해 만든다
      06-appearance 는 snapshot-appstore/<lang>/appearance/<테마>.png 여러 장을 기기마다 하나씩 겹쳐 놓는다
출력: fastlane/screenshots/<ASC 로케일>/<NN>_<슬러그>.png (1320×2868 / 알파 없음)
      같은 폴더의 duo_<NN>_<슬러그>.png — snapshot-appstore/<lang>/duo/ 원본을 그대로 옮긴다.
      캔버스가 화면 크기라 캡션 자리가 없다. deliver 가 해상도로 화면 종류를 가른다

기기 프레임은 애플 공식 베젤만 쓴다 (마케팅·아이덴티티 가이드라인). 동봉 라이선스가
non-transferable 이라 public 레포에 커밋하지 않고 캐시 디렉토리에 받아 쓴다.
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_bezel import load_bezel, screen_hole  # noqa: E402
from store_canvas import (  # noqa: E402
    UPLOAD_SIZE, compose, compose_theme_lineup, theme_lineup_screens,
)
from store_screen import home_screen, inset_screenshot  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

ALL_LANGS = [
    "en", "ko", "ja", "zh-Hans", "zh-Hant", "vi", "th", "es", "fr", "it", "pt-BR",
    "ca", "de", "nl", "sv", "da", "nb", "fi", "pl", "cs", "sk", "hu", "ru", "uk",
    "ro", "el", "hr", "tr", "id", "ms", "hi",
]

ASC_LOCALES = {
    "en": "en-US", "de": "de-DE", "es": "es-ES",
    "fr": "fr-FR", "nl": "nl-NL", "nb": "no",
}

SLUGS = [
    "01-calendar",
    "02-repeat-options",
    "03-event-detail",
    "04-google-event",
    "05-widgets",
    "06-appearance",
    "07-widget-style",
]

HOME_SCREEN_SLUG = "05-widgets"

THEME_LINEUP_SLUG = "06-appearance"

DUO_SLUGS = [
    "01-calendar-two-columns",
    "02-calendar-cover",
]
DUO_SIZES = [(2853, 2007), (1398, 2034)]
DUO_PREFIX = "duo_"


def asc_locale(lang):
    return ASC_LOCALES.get(lang, lang)


def upload_name(slug, prefix=""):
    number, _, rest = slug.partition("-")
    return f"{prefix}{number}_{rest}.png"


# MARK: - 합성

def screen_image(slug, source_dir, size):
    if slug == HOME_SCREEN_SLUG:
        return home_screen(source_dir, size)
    path = source_dir / f"{slug}.png"
    if not path.exists():
        raise SystemExit(f"  ✗ 누락: {path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")
    with Image.open(path) as screenshot:
        return inset_screenshot(screenshot.convert("RGBA"), size)


def compose_lang(lang, bezel, hole_mask, hole_box):
    source_dir = ROOT / "snapshot-appstore" / lang
    output_dir = ROOT / "fastlane/screenshots" / asc_locale(lang)
    output_dir.mkdir(parents=True, exist_ok=True)
    # 라인업 번호가 바뀌면 지난 회차 산출물이 남고, deliver 는 디렉토리째 올린다
    for stale in output_dir.glob("*.png"):
        stale.unlink()
    print(f"▶︎ [{lang}] 합성 → fastlane/screenshots/{asc_locale(lang)}/")

    hole_size = (hole_box[2] - hole_box[0], hole_box[3] - hole_box[1])
    for slug in SLUGS:
        caption_path = source_dir / "captions" / f"{slug}.png"
        if not caption_path.exists():
            raise SystemExit(f"  ✗ 누락: {caption_path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")

        with Image.open(caption_path) as caption:
            if slug == THEME_LINEUP_SLUG:
                screens = theme_lineup_screens(source_dir, hole_size)
                composed = compose_theme_lineup(screens, caption.convert("RGBA"), bezel, hole_mask, hole_box)
            else:
                screen = screen_image(slug, source_dir, hole_size)
                composed = compose(screen, caption.convert("RGBA"), bezel, hole_mask, hole_box)
        composed.save(output_dir / upload_name(slug))
    print(f"  ✓ [{lang}] {len(SLUGS)}장")
    return output_dir


def copy_duo_lang(lang, output_dir):
    source_dir = ROOT / "snapshot-appstore" / lang / "duo"
    print(f"▶︎ [{lang}] Duo 원본 → fastlane/screenshots/{asc_locale(lang)}/{DUO_PREFIX}*")

    for slug in DUO_SLUGS:
        path = source_dir / f"{slug}.png"
        if not path.exists():
            raise SystemExit(f"  ✗ 누락: {path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")
        with Image.open(path) as screenshot:
            screenshot.convert("RGB").save(output_dir / upload_name(slug, DUO_PREFIX))
    print(f"  ✓ [{lang}] Duo {len(DUO_SLUGS)}장")


def verify(output_dir, pattern, sizes):
    failures = []
    for path in sorted(output_dir.glob(pattern)):
        with Image.open(path) as image:
            if image.size not in sizes:
                failures.append(f"{path.name}: {image.size[0]}x{image.size[1]} — 규격 아님")
            if image.mode == "RGBA" or "transparency" in image.info:
                failures.append(f"{path.name}: 알파 채널이 남아 있다")
    if failures:
        print("\n".join(f"  ✗ {message}" for message in failures), file=sys.stderr)
        raise SystemExit(1)
    print(f"  ✓ {' / '.join(f'{width}x{height}' for width, height in sizes)} / 알파 없음")


def main(argv):
    langs = ALL_LANGS if argv[:1] == ["--all"] else argv
    if not langs:
        print(__doc__)
        raise SystemExit(1)

    bezel = load_bezel()
    hole_mask, hole_box = screen_hole(bezel)
    print(f"▶︎ 화면 구멍 {hole_box[2]-hole_box[0]}x{hole_box[3]-hole_box[1]} @ ({hole_box[0]}, {hole_box[1]})")

    for lang in langs:
        output_dir = compose_lang(lang, bezel, hole_mask, hole_box)
        copy_duo_lang(lang, output_dir)
        verify(output_dir, "[0-9]*.png", (UPLOAD_SIZE,))
        verify(output_dir, f"{DUO_PREFIX}*.png", DUO_SIZES)
    print(f"✓ 전체 완료 — {len(langs)} 개 언어")


if __name__ == "__main__":
    main(sys.argv[1:])
