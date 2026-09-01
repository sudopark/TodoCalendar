#!/usr/bin/env python3
"""촬영한 장면을 맞춤형 제품 페이지(CPP) 업로드용 스샷으로 합성한다.

usage:
    python3 scripts/compose-cpp-screenshots.py --locale <lang> [--page <page_id>]
    python3 scripts/compose-cpp-screenshots.py --all-locales

입력: snapshot-appstore/<lang>/ 촬영 산출물 + captions/cpp/<장면>.png
출력: fastlane/custom_product_pages/<page_id>/images/<ASC 로케일>/<NN>_<장면>.png (1320×2868 / 알파 없음)

기하는 `compose-appstore-screenshots.py` 와 같은 값을 쓴다 — 기본 스토어 페이지와 네 CPP 가
한 앱으로 보여야 한다 (명세 §4-1).

**인앱 이벤트와 달리 캡션을 이미지 안에 넣는다** — 스토어 스샷은 그게 표준이다 (명세 §4 서두).
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

ROOT = Path(__file__).resolve().parent.parent
# 회귀 테스트가 실제 원고를 안 건드리게 덮어쓸 수 있어야 한다 (asc-in-app-event.rb 의 ASC_SECRET_FILE 과 같은 처리)
CONFIG_ROOT = Path(os.environ.get("CPP_CONFIG_ROOT") or (ROOT / "fastlane" / "custom_product_pages"))

UPLOAD_SIZE = (1320, 2868)
CANVAS_COLOR = "#F5F5F7"
DEVICE_WIDTH = 1150
DEVICE_TOP = 620
CAPTION_TOP = 100
SCENES_PER_PAGE = 6

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


def load_pages():
    path = CONFIG_ROOT / "pages.json"
    if not path.exists():
        raise SystemExit(f"✗ {path.relative_to(ROOT)} 가 없다 — 페이지 구성을 먼저 만들어라")
    pages = json.loads(path.read_text())
    for page_id, config in pages.items():
        scenes = config.get("scenes") or []
        if len(scenes) != SCENES_PER_PAGE:
            raise SystemExit(
                f"✗ {page_id} 의 장면이 {len(scenes)}개다 — {SCENES_PER_PAGE}개여야 한다"
            )
    return pages


def upload_name(order, scene_id):
    return f"{order + 1:02d}_{scene_id}.png"


def compose_scene(scene_id, source_dir, caption, bezel, hole_mask, hole_box):
    hole_size = (hole_box[2] - hole_box[0], hole_box[3] - hole_box[1])
    screen = cpp_scenes.scene(scene_id, source_dir, hole_size)

    device = Image.new("RGBA", bezel.size, (0, 0, 0, 0))
    device.paste(screen, (hole_box[0], hole_box[1]), hole_mask.crop(hole_box))
    device.paste(bezel, (0, 0), bezel)

    device_height = round(DEVICE_WIDTH * bezel.height / bezel.width)
    device = device.resize((DEVICE_WIDTH, device_height), Image.LANCZOS)

    canvas = Image.new("RGB", UPLOAD_SIZE, CANVAS_COLOR)
    canvas.paste(caption.convert("RGB"), ((UPLOAD_SIZE[0] - caption.width) // 2, CAPTION_TOP))
    canvas.paste(device, ((UPLOAD_SIZE[0] - DEVICE_WIDTH) // 2, DEVICE_TOP), device)
    return canvas


def caption_image(scene_id, source_dir):
    path = source_dir / "captions" / "cpp" / f"{scene_id}.png"
    if not path.exists():
        raise SystemExit(
            f"✗ 누락: {path.relative_to(ROOT)} — "
            "captions.json 에 그 언어 원고를 넣고 다시 촬영해라"
        )
    return Image.open(path)


def compose_lang(lang, pages, bezel, hole_mask, hole_box):
    source_dir = ROOT / "snapshot-appstore" / lang
    # 한 장면이 여러 페이지에 다른 번호로 들어간다 — 로케일당 한 번만 합성한다
    needed = sorted({scene for config in pages.values() for scene in config["scenes"]})
    composed = {}
    for scene_id in needed:
        with caption_image(scene_id, source_dir) as caption:
            composed[scene_id] = compose_scene(
                scene_id, source_dir, caption, bezel, hole_mask, hole_box
            )

    out_dirs = []
    for page_id, config in pages.items():
        out = CONFIG_ROOT / page_id / "images" / asc_locale(lang)
        out.mkdir(parents=True, exist_ok=True)
        # 라인업이 바뀌면 지난 회차 산출물이 남고, 업로드는 디렉토리째 읽는다
        for stale in out.glob("*.png"):
            stale.unlink()
        for order, scene_id in enumerate(config["scenes"]):
            composed[scene_id].save(out / upload_name(order, scene_id))
        out_dirs.append(out)

    print(f"  ✓ [{lang}] 장면 {len(composed)}종 → {len(pages)}페이지 × {SCENES_PER_PAGE}장")
    return out_dirs


def verify(out_dirs, pages):
    """지침 §7 중 기계가 볼 수 있는 항목 — 해상도·알파·장수·라인업 순서."""
    failures = []
    for out in out_dirs:
        page_id = out.parent.parent.name
        expected = [
            upload_name(order, scene_id)
            for order, scene_id in enumerate(pages[page_id]["scenes"])
        ]
        actual = sorted(path.name for path in out.glob("*.png"))
        if actual != sorted(expected):
            failures.append(f"{out.relative_to(ROOT)}: 라인업이 다르다 — {actual}")
            continue
        for name in expected:
            with Image.open(out / name) as image:
                if image.size != UPLOAD_SIZE:
                    failures.append(f"{out.relative_to(ROOT)}/{name}: {image.size} — 규격 아님")
                if image.mode != "RGB" or "transparency" in image.info:
                    failures.append(f"{out.relative_to(ROOT)}/{name}: 알파가 남았다")
    if failures:
        print("\n".join(f"  ✗ {message}" for message in failures), file=sys.stderr)
        raise SystemExit(1)
    print(f"✓ {len(out_dirs)}개 페이지·로케일 × {SCENES_PER_PAGE}장 — 해상도·알파·라인업 순서 확인됨")
    print("  기계가 못 보는 항목은 스킬 체크리스트로: 캡션 오탈자 / 언어 혼용 없음 / 더미에 실명 없음 / MCP·타사 UI 없음")


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--locale")
    parser.add_argument("--all-locales", action="store_true")
    parser.add_argument("--page")
    args = parser.parse_args(argv)

    if args.all_locales:
        langs = ALL_LANGS
    elif args.locale:
        langs = [args.locale]
    else:
        raise SystemExit("✗ --locale <lang> 또는 --all-locales 중 하나가 필요하다")

    pages = load_pages()
    if args.page:
        if args.page not in pages:
            raise SystemExit(f"✗ 모르는 페이지: {args.page} — 아는 것은 {', '.join(pages)}")
        pages = {args.page: pages[args.page]}

    bezel = load_bezel()
    hole_mask, hole_box = screen_hole(bezel)

    out_dirs = [
        out for lang in langs
        for out in compose_lang(lang, pages, bezel, hole_mask, hole_box)
    ]
    verify(out_dirs, pages)


if __name__ == "__main__":
    main(sys.argv[1:])
