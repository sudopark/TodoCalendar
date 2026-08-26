#!/usr/bin/env python3
"""촬영한 화면 원본을 App Store 업로드용 마케팅 스샷으로 합성한다.

usage:
    python3 scripts/compose-appstore-screenshots.py <lang> [<lang> ...]
    python3 scripts/compose-appstore-screenshots.py --all

입력: snapshot-appstore/<lang>/<NN-슬러그>.png + snapshot-appstore/<lang>/captions/<NN-슬러그>.png
출력: fastlane/screenshots/<ASC 로케일>/<NN>_<슬러그>.png (1320×2868 / 알파 없음)

기기 프레임은 애플 공식 베젤만 쓴다 (마케팅·아이덴티티 가이드라인). 동봉 라이선스가
non-transferable 이라 public 레포에 커밋하지 않고 캐시 디렉토리에 받아 쓴다.
"""

import shutil
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

UPLOAD_SIZE = (1320, 2868)
CANVAS_COLOR = "#F5F5F7"
DEVICE_WIDTH = 1150
DEVICE_TOP = 620
CAPTION_TOP = 100
# iPhone 16 Pro Max 상단 safe area 62pt @3x — 콘텐츠가 Dynamic Island 밑에 깔리지 않게 한다
SCREEN_TOP_INSET = 186

BEZEL_URL = "https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-16.dmg"
BEZEL_IN_DMG = "PNG/iPhone 16 Pro Max/iPhone 16 Pro Max - Black Titanium - Portrait.png"
BEZEL_CACHE_DIR = Path.home() / "Library/Caches/todocalendar-appstore-bezel"
BEZEL_CACHE_PATH = BEZEL_CACHE_DIR / "iPhone-16-Pro-Max-Black-Titanium-Portrait.png"

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
    "04-event-types",
    "05-appearance",
]


def asc_locale(lang):
    return ASC_LOCALES.get(lang, lang)


def upload_name(slug):
    number, _, rest = slug.partition("-")
    return f"{number}_{rest}.png"


# MARK: - 베젤 확보

def download_bezel():
    BEZEL_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as workspace:
        dmg_path = Path(workspace) / "bezel.dmg"
        print(f"▶︎ 베젤 내려받는 중 — {BEZEL_URL}")
        subprocess.run(["curl", "-fsSL", "-o", str(dmg_path), BEZEL_URL], check=True)

        mount_point = Path(workspace) / "mount"
        mount_point.mkdir()
        # dmg 에 SLA 가 걸려 있어 동의 입력 없이는 attach 가 멈춘다
        subprocess.run(
            f'yes | hdiutil attach "{dmg_path}" -mountpoint "{mount_point}" -nobrowse -readonly',
            shell=True, check=True, capture_output=True,
        )
        try:
            source = mount_point / BEZEL_IN_DMG
            if not source.exists():
                raise SystemExit(f"✗ dmg 안에 {BEZEL_IN_DMG} 가 없다 — 베젤 배포 구조가 바뀌었다")
            shutil.copyfile(source, BEZEL_CACHE_PATH)
        finally:
            subprocess.run(["hdiutil", "detach", str(mount_point)], check=False, capture_output=True)
    print(f"  ✓ 캐시 — {BEZEL_CACHE_PATH}")


def load_bezel():
    if not BEZEL_CACHE_PATH.exists():
        download_bezel()
    return Image.open(BEZEL_CACHE_PATH).convert("RGBA")


def screen_hole(bezel):
    """베젤 갱신에도 안 깨지게 좌표를 박지 않고 알파 채널 flood-fill 로 화면 구멍을 찾는다."""
    transparent = bezel.getchannel("A").point(lambda alpha: 255 if alpha == 0 else 0)
    seed = (bezel.width // 2, bezel.height // 2)
    if transparent.getpixel(seed) != 255:
        raise SystemExit("✗ 베젤 중앙이 투명하지 않다 — 화면 구멍을 못 찾는다")
    ImageDraw.floodfill(transparent, seed, 128)
    mask = transparent.point(lambda value: 255 if value == 128 else 0)
    box = mask.getbbox()
    if box is None:
        raise SystemExit("✗ 화면 구멍 영역이 비었다")
    return mask, box


# MARK: - 합성

def inset_screenshot(screenshot, size):
    """상단에 화면 배경색 인셋을 둔 뒤 구멍 크기에 맞춰 자른다."""
    top_row = [screenshot.getpixel((x, 0)) for x in range(screenshot.width)]
    background = Counter(top_row).most_common(1)[0][0]
    inset = Image.new("RGBA", size, background)
    inset.paste(screenshot, (0, SCREEN_TOP_INSET))
    return inset


def compose(screenshot, caption, bezel, hole_mask, hole_box):
    hole_size = (hole_box[2] - hole_box[0], hole_box[3] - hole_box[1])
    device = Image.new("RGBA", bezel.size, (0, 0, 0, 0))
    device.paste(
        inset_screenshot(screenshot, hole_size),
        (hole_box[0], hole_box[1]),
        hole_mask.crop(hole_box),
    )
    device.paste(bezel, (0, 0), bezel)

    device_height = round(DEVICE_WIDTH * bezel.height / bezel.width)
    device = device.resize((DEVICE_WIDTH, device_height), Image.LANCZOS)

    canvas = Image.new("RGB", UPLOAD_SIZE, CANVAS_COLOR)
    canvas.paste(caption.convert("RGB"), ((UPLOAD_SIZE[0] - caption.width) // 2, CAPTION_TOP))
    canvas.paste(device, ((UPLOAD_SIZE[0] - DEVICE_WIDTH) // 2, DEVICE_TOP), device)
    return canvas


def compose_lang(lang, bezel, hole_mask, hole_box):
    source_dir = ROOT / "snapshot-appstore" / lang
    output_dir = ROOT / "fastlane/screenshots" / asc_locale(lang)
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"▶︎ [{lang}] 합성 → fastlane/screenshots/{asc_locale(lang)}/")

    for slug in SLUGS:
        screenshot_path = source_dir / f"{slug}.png"
        caption_path = source_dir / "captions" / f"{slug}.png"
        for path in (screenshot_path, caption_path):
            if not path.exists():
                raise SystemExit(f"  ✗ 누락: {path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")

        with Image.open(screenshot_path) as screenshot, Image.open(caption_path) as caption:
            composed = compose(
                screenshot.convert("RGBA"), caption.convert("RGBA"), bezel, hole_mask, hole_box
            )
        composed.save(output_dir / upload_name(slug))
    print(f"  ✓ [{lang}] {len(SLUGS)}장")
    return output_dir


def verify(output_dir):
    failures = []
    for path in sorted(output_dir.glob("*.png")):
        with Image.open(path) as image:
            if image.size != UPLOAD_SIZE:
                failures.append(f"{path.name}: {image.size[0]}x{image.size[1]} — 규격 아님")
            if image.mode == "RGBA" or "transparency" in image.info:
                failures.append(f"{path.name}: 알파 채널이 남아 있다")
    if failures:
        print("\n".join(f"  ✗ {message}" for message in failures), file=sys.stderr)
        raise SystemExit(1)
    print(f"  ✓ {UPLOAD_SIZE[0]}x{UPLOAD_SIZE[1]} / 알파 없음")


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
    print(f"✓ 전체 완료 — {len(langs)} 개 언어")


if __name__ == "__main__":
    main(sys.argv[1:])
