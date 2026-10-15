#!/usr/bin/env python3
"""촬영한 화면 원본을 App Store 업로드용 마케팅 스샷으로 합성한다.

usage:
    python3 scripts/compose-appstore-screenshots.py <lang> [<lang> ...]
    python3 scripts/compose-appstore-screenshots.py --all

입력: snapshot-appstore/<lang>/<NN-슬러그>.png + snapshot-appstore/<lang>/captions/<NN-슬러그>.png
      05-widgets 만 화면 원본이 없다 — snapshot-appstore/<lang>/widgets/ 의 위젯 원본을 홈화면으로 합성해 만든다
      06-appearance 는 snapshot-appstore/<lang>/appearance/<테마>.png 여러 장을 기기마다 하나씩 겹쳐 놓는다
출력: fastlane/screenshots/<ASC 로케일>/<NN>_<슬러그>.png (1320×2868 / 알파 없음)
      fastlane/screenshots_duo/<ASC 로케일>/<NN>_<슬러그>.png — snapshot-appstore/<lang>/duo/ 원본을 그대로 옮긴다.
      캔버스가 화면 크기라 캡션 자리가 없다. 6.9" 와 폴더를 나누는 이유는 fastlane/screenshots.md 의 Duo 절

기기 프레임은 애플 공식 베젤만 쓴다 (마케팅·아이덴티티 가이드라인). 동봉 라이선스가
non-transferable 이라 public 레포에 커밋하지 않고 캐시 디렉토리에 받아 쓴다.
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_bezel import load_bezel, screen_hole  # noqa: E402
from store_screen import home_screen, inset_screenshot  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

UPLOAD_SIZE = (1320, 2868)
CANVAS_COLOR = "#F5F5F7"
DEVICE_WIDTH = 1150
DEVICE_TOP = 620
CAPTION_TOP = 100

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
# 뒤(왼쪽 위)부터 앞(오른쪽 아래) 순서다 — 밝은 테마와 어두운 테마를 번갈아 둬야 겹친 경계가 보인다
THEME_LINEUP = ["indigo", "amethyst", "ruby", "wine"]
THEME_DEVICE_WIDTH = 760
THEME_DEVICE_MARGIN = 40
THEME_BOTTOM_OVERFLOW = 250

DUO_SLUGS = [
    "01-calendar-two-columns",
    "02-calendar-cover",
]
DUO_SIZES = [(2853, 2007), (1398, 2034)]


def asc_locale(lang):
    return ASC_LOCALES.get(lang, lang)


def upload_name(slug):
    number, _, rest = slug.partition("-")
    return f"{number}_{rest}.png"


# MARK: - 합성

def screen_image(slug, source_dir, size):
    if slug == HOME_SCREEN_SLUG:
        return home_screen(source_dir, size)
    path = source_dir / f"{slug}.png"
    if not path.exists():
        raise SystemExit(f"  ✗ 누락: {path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")
    with Image.open(path) as screenshot:
        return inset_screenshot(screenshot.convert("RGBA"), size)


def device_image(screen, bezel, hole_mask, hole_box, width):
    device = Image.new("RGBA", bezel.size, (0, 0, 0, 0))
    device.paste(screen, (hole_box[0], hole_box[1]), hole_mask.crop(hole_box))
    device.paste(bezel, (0, 0), bezel)
    height = round(width * bezel.height / bezel.width)
    return device.resize((width, height), Image.LANCZOS)


def caption_canvas(caption):
    canvas = Image.new("RGB", UPLOAD_SIZE, CANVAS_COLOR)
    canvas.paste(caption.convert("RGB"), ((UPLOAD_SIZE[0] - caption.width) // 2, CAPTION_TOP))
    return canvas


def compose(screen, caption, bezel, hole_mask, hole_box):
    device = device_image(screen, bezel, hole_mask, hole_box, DEVICE_WIDTH)
    canvas = caption_canvas(caption)
    canvas.paste(device, ((UPLOAD_SIZE[0] - DEVICE_WIDTH) // 2, DEVICE_TOP), device)
    return canvas


def theme_lineup_screens(source_dir, size):
    screens = []
    for key in THEME_LINEUP:
        path = source_dir / "appearance" / f"{key}.png"
        if not path.exists():
            raise SystemExit(f"  ✗ 누락: {path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")
        with Image.open(path) as screenshot:
            screens.append(inset_screenshot(screenshot.convert("RGBA"), size))
    return screens


def compose_theme_lineup(screens, caption, bezel, hole_mask, hole_box):
    """같은 화면을 테마별로 칠한 기기를 왼쪽 위에서 오른쪽 아래로 계단처럼 겹친다."""
    canvas = caption_canvas(caption)
    devices = [device_image(screen, bezel, hole_mask, hole_box, THEME_DEVICE_WIDTH) for screen in screens]
    left, right = THEME_DEVICE_MARGIN, UPLOAD_SIZE[0] - THEME_DEVICE_MARGIN - THEME_DEVICE_WIDTH
    top, bottom = DEVICE_TOP, UPLOAD_SIZE[1] - devices[0].height + THEME_BOTTOM_OVERFLOW
    steps = max(len(devices) - 1, 1)
    for index, device in enumerate(devices):
        position = (
            round(left + (right - left) * index / steps),
            round(top + (bottom - top) * index / steps),
        )
        canvas.paste(device, position, device)
    return canvas


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


def copy_duo_lang(lang):
    source_dir = ROOT / "snapshot-appstore" / lang / "duo"
    output_dir = ROOT / "fastlane/screenshots_duo" / asc_locale(lang)
    output_dir.mkdir(parents=True, exist_ok=True)
    for stale in output_dir.glob("*.png"):
        stale.unlink()
    print(f"▶︎ [{lang}] Duo 원본 → fastlane/screenshots_duo/{asc_locale(lang)}/")

    for slug in DUO_SLUGS:
        path = source_dir / f"{slug}.png"
        if not path.exists():
            raise SystemExit(f"  ✗ 누락: {path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")
        with Image.open(path) as screenshot:
            screenshot.convert("RGB").save(output_dir / upload_name(slug))
    print(f"  ✓ [{lang}] Duo {len(DUO_SLUGS)}장")
    return output_dir


def verify(output_dir, sizes=(UPLOAD_SIZE,)):
    failures = []
    for path in sorted(output_dir.glob("*.png")):
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
        verify(compose_lang(lang, bezel, hole_mask, hole_box))
        verify(copy_duo_lang(lang), DUO_SIZES)
    print(f"✓ 전체 완료 — {len(langs)} 개 언어")


if __name__ == "__main__":
    main(sys.argv[1:])
