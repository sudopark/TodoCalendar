#!/usr/bin/env python3
"""촬영한 장면을 App Store 크리에이티브 에셋(제품 페이지 헤더·검색 결과)으로 합성한다.

usage:
    python3 scripts/compose-creative-assets.py --locale <lang>
    python3 scripts/compose-creative-assets.py --all-locales

입력: snapshot-appstore/<lang>/ 촬영 산출물 + captions/creative/<captionKey>.png
출력: fastlane/creative_assets/images/<ASC 로케일>/header.png (3840×1646)
      fastlane/creative_assets/images/<ASC 로케일>/search.png (3840×2560)  — 둘 다 알파 없음

장면과 기기 목업은 맞춤형 제품 페이지와 같은 `cpp_scenes`·`store_canvas` 를 쓴다 — 가로 배치만 여기 몫이다.
헤더는 캡션을 왼쪽에 두고 기기를 오른쪽에 늘어놓고, 검색 결과는 캡션을 위에 두고 기기를 아래에 늘어놓는다.
"""

import argparse
import json
import os
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cpp_scenes  # noqa: E402
from device_bezel import load_bezel, screen_hole  # noqa: E402
from store_canvas import CANVAS_COLOR, device_image  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
# 회귀 테스트가 실제 원고를 안 건드리게 덮어쓸 수 있어야 한다 (compose-cpp-screenshots.py 의 CPP_CONFIG_ROOT 와 같은 처리)
CONFIG_ROOT = Path(os.environ.get("CREATIVE_CONFIG_ROOT") or (ROOT / "fastlane" / "creative_assets"))

MAX_SCENES = 3

# 배치마다 캔버스·기기 기하. 캡션은 test_creativeAssetCaptions 의 캔버스(@3x)이고, 칸보다 크면 비율을 지켜 줄인다
PLACEMENTS = {
    "header": {
        "size": (3840, 1646),
        "device_width": 700,
        "device_gap": 50,
        "margin": 140,
        "caption_side": "left",
    },
    "search": {
        "size": (3840, 2560),
        "device_width": 910,
        "device_gap": 120,
        "margin": 60,
        "caption_side": "top",
    },
}

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


def load_assets():
    path = CONFIG_ROOT / "assets.json"
    if not path.exists():
        raise SystemExit(f"✗ {path.relative_to(ROOT)} 가 없다 — 배치 구성을 먼저 만들어라")
    assets = json.loads(path.read_text())
    if sorted(assets) != sorted(PLACEMENTS):
        raise SystemExit(f"✗ assets.json 의 배치가 {sorted(assets)} 다 — {sorted(PLACEMENTS)} 여야 한다")
    for name, config in assets.items():
        scenes = config.get("scenes") or []
        if not 1 <= len(scenes) <= MAX_SCENES:
            raise SystemExit(f"✗ {name} 의 장면이 {len(scenes)}개다 — 1~{MAX_SCENES}개여야 한다")
        # 촬영 스크립트의 CREATIVE_CAPTION_MAPPING 이 배치 이름으로만 캡션을 뽑는다
        if config.get("captionKey") != name:
            raise SystemExit(f"✗ {name} 의 captionKey 가 {config.get('captionKey')!r} 다 — 배치 이름과 같아야 한다")
    return assets


def caption_image(caption_key, source_dir):
    path = source_dir / "captions" / "creative" / f"{caption_key}.png"
    if not path.exists():
        raise SystemExit(
            f"✗ 누락: {path.relative_to(ROOT)} — "
            "fastlane/creative_assets/captions.json 에 그 언어 원고를 넣고 다시 촬영해라"
        )
    with Image.open(path) as caption:
        return caption.convert("RGB")


def devices(scene_ids, source_dir, width, bezel, hole_mask, hole_box):
    hole_size = (hole_box[2] - hole_box[0], hole_box[3] - hole_box[1])
    return [
        device_image(cpp_scenes.scene(scene_id, source_dir, hole_size), bezel, hole_mask, hole_box, width)
        for scene_id in scene_ids
    ]


def fitted(image, box_size):
    """캡션이 칸보다 크면 비율을 지켜 줄인다 — 작으면 그대로 둔다."""
    ratio = min(box_size[0] / image.width, box_size[1] / image.height, 1)
    if ratio == 1:
        return image
    return image.resize((round(image.width * ratio), round(image.height * ratio)), Image.LANCZOS)


def paste_centered(canvas, image, box):
    left, top, right, bottom = box
    image = fitted(image, (right - left, bottom - top))
    canvas.paste(image, (left + (right - left - image.width) // 2, top + (bottom - top - image.height) // 2))


def compose(placement, caption, mockups):
    """기기 줄과 캡션 칸을 배치 방향에 따라 나눈다 — 헤더는 좌우, 검색 결과는 위아래."""
    width, height = placement["size"]
    margin, gap = placement["margin"], placement["device_gap"]
    canvas = Image.new("RGB", placement["size"], CANVAS_COLOR)
    row_width = sum(device.width for device in mockups) + gap * (len(mockups) - 1)
    device_height = mockups[0].height

    if placement["caption_side"] == "left":
        row_left = width - margin - row_width
        row_top = (height - device_height) // 2
        paste_centered(canvas, caption, (margin, 0, row_left - margin, height))
    else:
        row_left = (width - row_width) // 2
        row_top = height - margin - device_height
        paste_centered(canvas, caption, (0, margin, width, row_top - margin))

    for index, device in enumerate(mockups):
        canvas.paste(device, (row_left + index * (device.width + gap), row_top), device)
    return canvas


def compose_lang(lang, assets, bezel, hole_mask, hole_box):
    source_dir = ROOT / "snapshot-appstore" / lang
    out = CONFIG_ROOT / "images" / asc_locale(lang)
    composed = {}
    for name, config in assets.items():
        placement = PLACEMENTS[name]
        caption = caption_image(config["captionKey"], source_dir)
        mockups = devices(config["scenes"], source_dir, placement["device_width"], bezel, hole_mask, hole_box)
        composed[name] = compose(placement, caption, mockups)

    out.mkdir(parents=True, exist_ok=True)
    # 합성이 다 끝난 뒤에 지운다 — 중간에 끊기면 지난 회차 산출물이 그대로 남는다
    for stale in out.glob("*.png"):
        stale.unlink()
    for name, image in composed.items():
        image.save(out / f"{name}.png", format="PNG")

    print(f"  ✓ [{lang}] {', '.join(assets)} → {out.relative_to(ROOT)}")
    return out


def verify(out_dirs):
    """업로드 가드(asc-creative-assets.rb)가 보는 항목을 합성 직후에 먼저 본다 — 해상도·알파·PNG·두 파일."""
    failures = []
    for out in out_dirs:
        for name, placement in PLACEMENTS.items():
            path = out / f"{name}.png"
            if not path.exists():
                failures.append(f"{path.relative_to(ROOT)}: 없다")
                continue
            with Image.open(path) as image:
                if image.format != "PNG":
                    failures.append(f"{path.relative_to(ROOT)}: {image.format} — PNG 가 아니다")
                if image.size != placement["size"]:
                    failures.append(f"{path.relative_to(ROOT)}: {image.size} — 규격 아님")
                if image.mode != "RGB" or "transparency" in image.info:
                    failures.append(f"{path.relative_to(ROOT)}: 알파가 남았다")
    if failures:
        print("\n".join(f"  ✗ {message}" for message in failures), file=sys.stderr)
        raise SystemExit(1)
    print(f"✓ {len(out_dirs)}개 로케일 × {len(PLACEMENTS)}종 — 해상도·알파·PNG 확인됨")
    print("  기계가 못 보는 항목은 스킬 체크리스트로: 캡션 오탈자 / 언어 혼용 없음 / 캡션이 기기와 안 겹침")


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--locale")
    parser.add_argument("--all-locales", action="store_true")
    args = parser.parse_args(argv)

    if args.all_locales:
        langs = ALL_LANGS
    elif args.locale:
        langs = [args.locale]
    else:
        raise SystemExit("✗ --locale <lang> 또는 --all-locales 중 하나가 필요하다")

    assets = load_assets()
    bezel = load_bezel()
    hole_mask, hole_box = screen_hole(bezel)

    out_dirs = [compose_lang(lang, assets, bezel, hole_mask, hole_box) for lang in langs]
    verify(out_dirs)


if __name__ == "__main__":
    main(sys.argv[1:])
