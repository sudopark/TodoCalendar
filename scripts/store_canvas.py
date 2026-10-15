#!/usr/bin/env python3
"""App Store 업로드 캔버스 조립 — 캡션 아래에 기기 목업을 얹어 1320×2868 한 장을 만든다.

기본 스토어 페이지(`compose-appstore-screenshots.py`)와 맞춤형 제품 페이지(`compose-cpp-screenshots.py`)가
같은 기하를 써야 다섯 라인업이 한 앱으로 보인다 (CPP 명세 §4-1).

화면 한 장을 만드는 일은 `store_screen.py` 가 맡는다.
"""

from PIL import Image

from store_screen import ROOT, inset_screenshot

UPLOAD_SIZE = (1320, 2868)
CANVAS_COLOR = "#F5F5F7"
DEVICE_WIDTH = 1150
DEVICE_TOP = 620
CAPTION_TOP = 100

# 뒤(왼쪽 위)부터 앞(오른쪽 아래) 순서다 — 밝은 테마와 어두운 테마를 번갈아 둬야 겹친 경계가 보인다
THEME_LINEUP = ["indigo", "amethyst", "ruby", "wine"]
THEME_DEVICE_WIDTH = 760
THEME_DEVICE_MARGIN = 40
THEME_BOTTOM_OVERFLOW = 250


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
