#!/usr/bin/env python3
"""촬영한 장면을 App Store 앱 내 이벤트 업로드용 이미지로 합성한다.

usage:
    python3 scripts/compose-event-images.py --event <event_id> --locale <lang>
    python3 scripts/compose-event-images.py --event <event_id> --all-locales

입력: snapshot-event/<event_id>/<lang>/s1-card-source.png, s2-detail-source.png
출력: fastlane/in_app_events/<event_id>/images/<ASC 로케일>/event-card_1920x1080.png
      fastlane/in_app_events/<event_id>/images/<ASC 로케일>/event-detail_1080x1920.png

기하 규칙의 정본은 유저의 "[공통 지침] 앱 내 이벤트 이미지 합성 파이프라인" 문서다.
이벤트마다 바뀌는 값은 전부 event.json 의 style 에 있어, 새 이벤트는 코드 수정 없이 돈다.

**이미지에 홍보 문구를 그리지 않는다.** App Store 가 이벤트 이름·설명을 카드 하단에 겹쳐
렌더링하므로 여기서 얹으면 겹친다 (지침 §2-5·§3-4).
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parent))
from device_bezel import load_bezel, screen_hole  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

CARD_SIZE = (1920, 1080)
DETAIL_SIZE = (1080, 1920)

# App Store 가 이벤트 이름·설명을 카드 하단 1/3 에 겹쳐 그린다 — 목업이 침범하면 안 된다
CARD_CLEAR_TOP = 720
# 시스템 UI 크롭 대비 좌우 여백
CARD_SIDE_MARGIN = 96
CARD_DEVICE_BOTTOM = 680
TILT_RANGE = (5, 10)
# 카드에 기기를 여러 대 세울 때 — 가운데가 히어로, 나머지는 뒤로 물러난다
CARD_FLANK_SCALE = 0.8
CARD_FLANK_SPREAD = 0.85

CARD_SOURCE_STEM = "s1-card-source"
DETAIL_SOURCE = "s2-detail-source.png"

# 잘려도 의미가 통해야 하는 영역 — 핵심 콘텐츠는 그 사이 중앙 밴드에 온다
DETAIL_SAFE_TOP = 240
DETAIL_SAFE_BOTTOM = 320

ALL_LANGS = [
    "en", "ko", "ja", "zh-Hans", "zh-Hant", "vi", "th", "es", "fr", "it", "pt-BR",
    "ca", "de", "nl", "sv", "da", "nb", "fi", "pl", "cs", "sk", "hu", "ru", "uk",
    "ro", "el", "hr", "tr", "id", "ms", "hi",
]
# lproj ↔ ASC 로케일이 다른 6개 (fastlane/metadata/README.md 매핑표와 같은 값)
ASC_LOCALES = {
    "en": "en-US", "de": "de-DE", "es": "es-ES",
    "fr": "fr-FR", "nl": "nl-NL", "nb": "no",
}


def asc_locale(lang):
    return ASC_LOCALES.get(lang, lang)


def rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def card_background(style):
    top, bottom = rgb(style["backgroundTop"]), rgb(style["backgroundBottom"])
    width, height = CARD_SIZE
    background = Image.new("RGB", CARD_SIZE)
    for y in range(height):
        ratio = y / (height - 1)
        row = tuple(round(top[c] + (bottom[c] - top[c]) * ratio) for c in range(3))
        background.paste(row, (0, y, width, y + 1))
    return background


def device_mockup(screenshot, bezel, hole_mask, hole_box, tilt):
    """스크린샷을 베젤 화면 구멍에 넣고 기울인다. 반환값은 알파를 가진 RGBA."""
    hole_width = hole_box[2] - hole_box[0]
    hole_height = hole_box[3] - hole_box[1]
    fitted = screenshot.convert("RGB").resize((hole_width, hole_height), Image.LANCZOS)

    screen = Image.new("RGBA", bezel.size, (0, 0, 0, 0))
    screen.paste(fitted, hole_box[:2])
    screen.putalpha(hole_mask)

    device = Image.alpha_composite(screen, bezel)
    return device.rotate(tilt, resample=Image.BICUBIC, expand=True)


def card_device(screenshot, height, tilt, bezel, hole_mask, hole_box):
    aspect = bezel.width / bezel.height
    scaled = bezel.resize((round(height * aspect), height), Image.LANCZOS)
    scaled_mask = hole_mask.resize(scaled.size, Image.LANCZOS)
    scaled_box = tuple(round(value * height / bezel.height) for value in hole_box)
    return device_mockup(screenshot, scaled, scaled_mask, scaled_box, tilt)


def compose_card(screenshots, style, bezel, hole_mask, hole_box):
    tilt = style.get("cardTiltDegrees", 7)
    if not TILT_RANGE[0] <= tilt <= TILT_RANGE[1]:
        raise SystemExit(f"✗ cardTiltDegrees={tilt} — 허용 범위는 5~10 이다 (지침 §2-2)")

    height = style.get("cardDeviceHeight", 1100)
    flank_scale = style.get("cardFlankScale", CARD_FLANK_SCALE)
    spread = style.get("cardFlankSpread", CARD_FLANK_SPREAD)
    hero = len(screenshots) // 2

    devices = [
        card_device(
            shot, round(height * (1 if index == hero else flank_scale)),
            tilt, bezel, hole_mask, hole_box
        )
        for index, shot in enumerate(screenshots)
    ]

    background = card_background(style)
    card = background.copy()
    # 플랭크를 먼저 깔고 히어로를 맨 위에 — 히어로가 좌우를 덮어야 앞에 선 것으로 읽힌다
    for index in sorted(range(len(devices)), key=lambda i: i == hero):
        device = devices[index]
        step = (devices[hero].width + device.width) / 2 * spread
        center = round(CARD_SIZE[0] / 2 + step * (index - hero))
        card.paste(device, (center - device.width // 2, CARD_DEVICE_BOTTOM - device.height), device)

    verify_card_clearances(card, background)
    return card


def verify_card_clearances(card, background):
    """배치 산식이 아니라 그려진 픽셀을 본다.

    `top` 을 `CARD_DEVICE_BOTTOM - device.height` 로 잡으면 `top + device.height` 는 항상
    그 상수라, 산식으로 하단 침범을 판정하면 무엇을 바꿔도 참이 안 되는 죽은 가드가 된다.
    """
    region = (0, CARD_CLEAR_TOP, CARD_SIZE[0], CARD_SIZE[1])
    if card.crop(region).tobytes() != background.crop(region).tobytes():
        raise SystemExit(
            f"✗ 하단 1/3(y>={CARD_CLEAR_TOP})에 배경 아닌 픽셀이 있다 — "
            "App Store 가 이벤트 이름·설명을 겹쳐 그리는 자리다. style.cardDeviceHeight 를 줄여라"
        )

    drawn = ImageChops.difference(card, background).getbbox()
    if drawn is None:
        raise SystemExit("✗ 배경만 남았다 — 소스 장면이나 베젤이 비었다")
    if drawn[0] < CARD_SIDE_MARGIN or drawn[2] > CARD_SIZE[0] - CARD_SIDE_MARGIN:
        raise SystemExit(
            f"✗ 목업이 좌우 여백 {CARD_SIDE_MARGIN}px 를 침범했다 (x {drawn[0]}~{drawn[2]}) — "
            "style.cardFlankSpread 를 줄여라"
        )


def compose_detail(screenshot):
    """풀블리드 — 짧은 축에 맞춰 덮고 중앙 밴드를 남기며 잘라낸다."""
    target_width, target_height = DETAIL_SIZE
    source = screenshot.convert("RGB")
    scale = max(target_width / source.width, target_height / source.height)
    scaled = source.resize((round(source.width * scale), round(source.height * scale)), Image.LANCZOS)

    left = (scaled.width - target_width) // 2
    top = (scaled.height - target_height) // 2
    return scaled.crop((left, top, left + target_width, top + target_height))


def card_source_paths(source_dir):
    """s1-card-source.png, -2, -3 … 을 붙은 데까지 순서대로 — 기기 좌→우 순이다."""
    paths = []
    while True:
        index = len(paths)
        name = f"{CARD_SOURCE_STEM}.png" if index == 0 else f"{CARD_SOURCE_STEM}-{index + 1}.png"
        path = source_dir / name
        if not path.exists():
            return paths
        paths.append(path)


def compose_lang(event_id, lang, style, bezel, hole_mask, hole_box):
    source_dir = ROOT / "snapshot-event" / event_id / lang
    card_paths = card_source_paths(source_dir)
    missing = [] if card_paths else [f"{CARD_SOURCE_STEM}.png"]
    if not (source_dir / DETAIL_SOURCE).exists():
        missing.append(DETAIL_SOURCE)
    if missing:
        raise SystemExit(f"✗ [{lang}] 소스 장면이 없다: {', '.join(missing)} — 먼저 촬영해라")

    out = ROOT / "fastlane" / "in_app_events" / event_id / "images" / asc_locale(lang)
    out.mkdir(parents=True, exist_ok=True)

    card_sources = [Image.open(path) for path in card_paths]
    try:
        card = compose_card(card_sources, style, bezel, hole_mask, hole_box)
    finally:
        for source in card_sources:
            source.close()
    card.save(out / "event-card_1920x1080.png")

    with Image.open(source_dir / DETAIL_SOURCE) as detail_source:
        compose_detail(detail_source).save(out / "event-detail_1080x1920.png")
    return out


def verify(out_dirs):
    """지침 §6 중 기계가 볼 수 있는 항목 — 해상도·알파·산출물 트리."""
    expected = {"event-card_1920x1080.png": CARD_SIZE, "event-detail_1080x1920.png": DETAIL_SIZE}
    failures = []
    for out in out_dirs:
        for name, size in expected.items():
            path = out / name
            if not path.exists():
                failures.append(f"{path.relative_to(ROOT)}: 없다")
                continue
            with Image.open(path) as image:
                if image.size != size:
                    failures.append(f"{path.relative_to(ROOT)}: {image.size} — {size} 아님")
                if image.mode != "RGB":
                    failures.append(f"{path.relative_to(ROOT)}: mode={image.mode} — 알파가 남았다")
    if failures:
        raise SystemExit("\n".join(f"  ✗ {line}" for line in failures))
    print(f"✓ {len(out_dirs)}개 로케일 × 2장 — 해상도·알파 확인됨")
    print("  기계가 못 보는 항목은 스킬 체크리스트로: 홍보 문구 없음 / 언어 혼용 없음 / 더미 데이터에 실명 없음")


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--event", required=True)
    parser.add_argument("--locale")
    parser.add_argument("--all-locales", action="store_true")
    args = parser.parse_args(argv)

    config_path = ROOT / "fastlane" / "in_app_events" / args.event / "event.json"
    if not config_path.exists():
        raise SystemExit(f"✗ {config_path} 가 없다 — 이벤트 설정을 먼저 만들어라")
    style = json.loads(config_path.read_text())["style"]

    if args.all_locales:
        langs = ALL_LANGS
    elif args.locale:
        langs = [args.locale]
    else:
        raise SystemExit("✗ --locale <lang> 또는 --all-locales 중 하나가 필요하다")

    bezel = load_bezel()
    hole_mask, hole_box = screen_hole(bezel)

    out_dirs = [compose_lang(args.event, lang, style, bezel, hole_mask, hole_box) for lang in langs]
    verify(out_dirs)


if __name__ == "__main__":
    main(sys.argv[1:])
