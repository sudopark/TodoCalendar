#!/usr/bin/env python3
"""맞춤형 제품 페이지(CPP) 장면 C1~C8 을 목업 구멍 크기의 화면 한 장으로 만든다.

명세의 장면 목록은 유저 문서 `CPP지침-맞춤형-제품-페이지-3종-명세.md` §2 가 정본이다.
입력은 전부 `scripts/capture-appstore-screenshots.sh` 가 언어별로 남긴 촬영 산출물이고,
조립이 필요한 장면(잠금화면·홈화면·AI 시트)은 각 전용 모듈이 맡는다.
"""

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ai_sheet  # noqa: E402
import lock_screen  # noqa: E402
import store_screen  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

CALENDAR_SCREEN = "01-calendar"
# lock_screen.compose 의 인자 순서 — 인라인·다음 일정·남은 시간·라이브 액티비티
LOCK_SCREEN_WIDGETS = [
    "lockscreen-foremost", "lockscreen-next", "lockscreen-next-remain", "lockscreen-live-activity"
]


def opened(path):
    if not path.exists():
        raise SystemExit(
            f"✗ 누락: {path.relative_to(ROOT)} — "
            "scripts/capture-appstore-screenshots.sh 로 그 언어를 먼저 촬영해라"
        )
    return Image.open(path)


def lock_screen_scene(source_dir, size):
    pieces = [opened(source_dir / "widgets" / f"{name}.png") for name in LOCK_SCREEN_WIDGETS]
    return lock_screen.compose(*pieces)


def home_screen_scene(source_dir, size):
    return store_screen.home_screen(source_dir, size)


def app_screen_scene(slug, top_inset=True):
    """`top_inset` 은 상단 safe area 자리를 여기서 만들지 여부다.

    인셋은 화면을 아래로 밀고 넘치는 만큼을 버리므로, 하단에 고정 UI 가 있는 화면은 꺼야 한다 —
    그런 화면은 촬영 케이스가 safe area 를 이미 포함해 찍는다.
    """
    def build(source_dir, size):
        with opened(source_dir / f"{slug}.png") as screenshot:
            if not top_inset:
                return screenshot.convert("RGB")
            return store_screen.inset_screenshot(screenshot.convert("RGBA"), size)
    return build


def ai_sheet_scene(sheet_name):
    """캘린더 위에 시트가 떠 있는 화면 — 배경도 상단 인셋을 거쳐야 헤더가 화면 끝에 안 붙는다."""
    def build(source_dir, size):
        background = app_screen_scene(CALENDAR_SCREEN)(source_dir, size)
        with opened(source_dir / "sheets" / f"{sheet_name}.png") as sheet:
            return ai_sheet.compose(background, sheet, screen_size=size)
    return build


SCENES = {
    "C1": lock_screen_scene,
    "C2": home_screen_scene,
    "C3": app_screen_scene("01-calendar"),
    "C4": app_screen_scene("07-todo-list"),
    "C5": app_screen_scene("03-event-detail"),
    # 공유 화면은 하단에 공유하기 버튼이 고정돼 있다 — 촬영이 safe area 를 이미 포함한다
    "C6": app_screen_scene("08-share-preview", top_inset=False),
    "C7": ai_sheet_scene("ai-command-processing"),
    "C8": ai_sheet_scene("ai-command-done"),
}


def scene(scene_id, source_dir, size):
    """`size` 는 베젤 화면 구멍 크기다 — 반환값이 그와 다르면 목업에 안 맞는다."""
    build = SCENES.get(scene_id)
    if build is None:
        raise SystemExit(f"✗ 모르는 장면: {scene_id} — 아는 것은 {', '.join(sorted(SCENES))}")
    composed = build(source_dir, size).convert("RGB")
    return composed if composed.size == size else composed.resize(size, Image.LANCZOS)
