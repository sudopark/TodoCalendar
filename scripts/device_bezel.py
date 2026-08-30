#!/usr/bin/env python3
"""아이폰 기기 베젤(목업) 확보와 화면 구멍 산출.

애플 공식 베젤만 쓴다 (마케팅·아이덴티티 가이드라인). 동봉 라이선스가 non-transferable 이라
public 레포에 커밋하지 않고 캐시 디렉토리에 받아 쓴다.
"""

import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

BEZEL_URL = "https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-16.dmg"
BEZEL_IN_DMG = "PNG/iPhone 16 Pro Max/iPhone 16 Pro Max - Black Titanium - Portrait.png"
BEZEL_CACHE_DIR = Path.home() / "Library/Caches/todocalendar-appstore-bezel"
BEZEL_CACHE_PATH = BEZEL_CACHE_DIR / "iPhone-16-Pro-Max-Black-Titanium-Portrait.png"


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
        raise SystemExit("✗ 화면 구멍 영역이 비었다 — 베젤 알파 구조가 바뀌었다")
    return mask, box
