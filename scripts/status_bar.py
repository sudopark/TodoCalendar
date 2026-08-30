#!/usr/bin/env python3
"""앱 화면 스냅샷에 상태창 자리를 낸다.

스냅샷은 safe area 없이 콘텐츠만 찍혀 나와, 목업에 넣으면 헤더가 화면 맨 위에 붙어
실제 기기와 다르게 보인다. 상태창 자체는 그리지 않는다 — App Store 이미지 스펙이
요구하지 않고, `compose-appstore-screenshots.py` 도 그리지 않는다.
"""

from PIL import Image

LOGICAL_HEIGHT = 874           # iPhone 17 포인트 높이
SAFE_AREA_TOP = 59             # 다이나믹 아일랜드 기기의 상단 safe area
STATUS_RATIO = SAFE_AREA_TOP / LOGICAL_HEIGHT


def inset(screen):
    """상단에 상태창 자리를 만든다 — 화면 배경색 띠를 덧대고 그만큼 하단을 잘라 비율을 지킨다."""
    source = screen.convert("RGB")
    height = round(source.height * STATUS_RATIO)
    result = Image.new("RGB", source.size, source.getpixel((2, 2)))
    result.paste(source.crop((0, 0, source.width, source.height - height)), (0, height))
    return result
