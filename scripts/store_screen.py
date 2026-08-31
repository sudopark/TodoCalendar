#!/usr/bin/env python3
"""App Store 규격 화면 조립 — 촬영 원본에 상단 인셋을 두거나, 위젯을 홈화면으로 얹는다.

목업 구멍에 그대로 들어갈 크기의 화면 한 장을 만드는 것이 이 모듈의 전부다.
기본 스토어 페이지(`compose-appstore-screenshots.py`)와 맞춤형 제품 페이지(`cpp_scenes.py`)가
같은 화면을 써야 두 라인업의 톤이 갈리지 않는다.

잠금화면판은 `lock_screen.py`, 시트 오버레이는 `ai_sheet.py` 가 같은 자리를 맡는다.
"""

from collections import Counter
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent

# iPhone 16 Pro Max 상단 safe area 62pt @3x — 콘텐츠가 Dynamic Island 밑에 깔리지 않게 한다
SCREEN_TOP_INSET = 186

HOME_SCREEN_WIDGETS = ["today-and-next", "month"]
# 라이트 테마 위젯이 떠 보이는 배경 — 홈화면 벽지 자리라 앱 컬러셋과 무관하다
WALLPAPER_TOP_COLOR = (58, 74, 128)
WALLPAPER_BOTTOM_COLOR = (146, 122, 168)
WIDGET_RADIUS = 78                  # 위젯 코너 26pt @3x — 캡처에 구워진 곡률과 같은 값
WIDGET_TOP = 430
WIDGET_GAP = 90
WIDGET_SHADOW_BLUR = 34
WIDGET_SHADOW_OFFSET = 14
WIDGET_SHADOW_ALPHA = 90


def inset_screenshot(screenshot, size, top_inset=SCREEN_TOP_INSET):
    """상단에 화면 배경색 인셋을 둔 뒤 구멍 크기에 맞춰 자른다."""
    top_row = [screenshot.getpixel((x, 0)) for x in range(screenshot.width)]
    background = Counter(top_row).most_common(1)[0][0]
    inset = Image.new("RGBA", size, background)
    inset.paste(screenshot, (0, top_inset))
    return inset


def wallpaper(size):
    width, height = size
    column = Image.new("RGB", (1, height))
    painter = ImageDraw.Draw(column)
    for y in range(height):
        ratio = y / (height - 1)
        painter.point((0, y), tuple(
            round(top + (bottom - top) * ratio)
            for top, bottom in zip(WALLPAPER_TOP_COLOR, WALLPAPER_BOTTOM_COLOR)
        ))
    return column.resize((width, height), Image.BILINEAR).convert("RGBA")


def trim_widget_margin(capture):
    """위젯 캡처엔 위젯 바깥 여백이 함께 들어 있다 — 그대로 얹으면 카드 테두리가 이중으로 보인다."""
    opaque = capture.convert("RGB")
    background = Image.new("RGB", opaque.size, opaque.getpixel((0, 0)))
    difference = ImageChops.difference(opaque, background).convert("L")
    box = difference.point(lambda value: 255 if value > 6 else 0).getbbox()
    if box is None:
        raise SystemExit("✗ 위젯 캡처가 배경색 한 장이다 — 잘라낼 내용이 없다")
    return capture.crop(box)


def rounded(widget, radius):
    mask = Image.new("L", widget.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, widget.width - 1, widget.height - 1], radius=radius, fill=255
    )
    shaped = widget.convert("RGBA")
    shaped.putalpha(mask)
    return shaped


def paste_with_shadow(screen, widget, position):
    shadow = Image.new("RGBA", screen.size, (0, 0, 0, 0))
    cast = Image.new("RGBA", widget.size, (0, 0, 0, WIDGET_SHADOW_ALPHA))
    cast.putalpha(widget.getchannel("A").point(lambda alpha: alpha * WIDGET_SHADOW_ALPHA // 255))
    shadow.paste(cast, (position[0], position[1] + WIDGET_SHADOW_OFFSET), cast)
    screen.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(WIDGET_SHADOW_BLUR)))
    screen.alpha_composite(widget, position)


def home_screen(source_dir, size, widget_names=None):
    widgets = []
    for name in widget_names or HOME_SCREEN_WIDGETS:
        path = source_dir / "widgets" / f"{name}.png"
        if not path.exists():
            raise SystemExit(f"  ✗ 누락: {path.relative_to(ROOT)} — 먼저 촬영 스크립트를 돌려라")
        with Image.open(path) as capture:
            widgets.append(rounded(trim_widget_margin(capture), WIDGET_RADIUS))

    screen = wallpaper(size)
    top = WIDGET_TOP
    for widget in widgets:
        paste_with_shadow(screen, widget, ((size[0] - widget.width) // 2, top))
        top += widget.height + WIDGET_GAP
    return screen
