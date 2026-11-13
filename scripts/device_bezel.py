#!/usr/bin/env python3
"""기기 베젤(목업) 확보와 화면 구멍 산출.

애플 공식 베젤만 쓴다 (마케팅·아이덴티티 가이드라인). 동봉 라이선스가 non-transferable 이라
public 레포에 커밋하지 않고 캐시 디렉토리에 받아 쓴다.
"""

import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw

BEZEL_CACHE_DIR = Path.home() / "Library/Caches/todocalendar-appstore-bezel"


@dataclass(frozen=True)
class BezelSpec:
    url: str
    path_in_dmg: str
    cache_name: str

    @property
    def cache_path(self):
        return BEZEL_CACHE_DIR / self.cache_name


IPHONE_BEZEL = BezelSpec(
    url="https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-16.dmg",
    path_in_dmg="PNG/iPhone 16 Pro Max/iPhone 16 Pro Max - Black Titanium - Portrait.png",
    cache_name="iPhone-16-Pro-Max-Black-Titanium-Portrait.png",
)
IPAD_BEZEL_URL = "https://devimages-cdn.apple.com/design/resources/download/Bezel-iPad-Pro-(M5).dmg"
IPAD_PORTRAIT_BEZEL = BezelSpec(
    url=IPAD_BEZEL_URL,
    path_in_dmg='PNG/iPad Pro (M5) 13" - Space Black - Portrait.png',
    cache_name="iPad-Pro-M5-13-Space-Black-Portrait.png",
)
IPAD_LANDSCAPE_BEZEL = BezelSpec(
    url=IPAD_BEZEL_URL,
    path_in_dmg='PNG/iPad Pro (M5) 13" - Space Black - Landscape.png',
    cache_name="iPad-Pro-M5-13-Space-Black-Landscape.png",
)
DUO_BEZEL_URL = "https://devimages-cdn.apple.com/design/resources/download/Bezel-iPhone-Duo.dmg"
DUO_INNER_BEZEL = BezelSpec(
    url=DUO_BEZEL_URL,
    path_in_dmg="PNG/iPhone Duo - Night Sky - Inner Open Landscape.png",
    cache_name="iPhone-Duo-Night-Sky-Inner-Open-Landscape.png",
)
DUO_COVER_BEZEL = BezelSpec(
    url=DUO_BEZEL_URL,
    path_in_dmg="PNG/iPhone Duo - Night Sky - Outer Closed Portrait.png",
    cache_name="iPhone-Duo-Night-Sky-Outer-Closed-Portrait.png",
)


def download_bezel(spec=IPHONE_BEZEL):
    BEZEL_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as workspace:
        dmg_path = Path(workspace) / "bezel.dmg"
        print(f"▶︎ 베젤 내려받는 중 — {spec.url}")
        subprocess.run(["curl", "-fsSL", "-o", str(dmg_path), spec.url], check=True)

        mount_point = Path(workspace) / "mount"
        mount_point.mkdir()
        # dmg 에 SLA 가 걸려 있어 동의 입력 없이는 attach 가 멈춘다
        subprocess.run(
            f'yes | hdiutil attach "{dmg_path}" -mountpoint "{mount_point}" -nobrowse -readonly',
            shell=True, check=True, capture_output=True,
        )
        try:
            source = mount_point / spec.path_in_dmg
            if not source.exists():
                raise SystemExit(f"✗ dmg 안에 {spec.path_in_dmg} 가 없다 — 베젤 배포 구조가 바뀌었다")
            shutil.copyfile(source, spec.cache_path)
        finally:
            subprocess.run(["hdiutil", "detach", str(mount_point)], check=False, capture_output=True)
    print(f"  ✓ 캐시 — {spec.cache_path}")


def load_bezel(spec=IPHONE_BEZEL):
    if not spec.cache_path.exists():
        download_bezel(spec)
    return Image.open(spec.cache_path).convert("RGBA")


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
