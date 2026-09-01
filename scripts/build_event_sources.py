#!/usr/bin/env python3
"""촬영된 카탈로그 산출물에서 이벤트 소스 장면(s1/s2)을 만든다.

usage: python3 scripts/build_event_sources.py <event_id> <lang>

event.json 의 scenes 값은 셋 중 하나이고, 조립 조각도 같은 셋이라 재귀로 푼다:
  - 문자열   — snapshot-catalog 기준 상대 경로
  - {"from": "snapshot-appstore", "file": "..."} — 앱스토어 스샷 파이프라인의 **캡션 얹기 전 원본**을
    언어별로 가져온다. 캡션이 구워진 fastlane/screenshots 쪽은 홍보 문구 금지 조항에 걸려 못 쓴다
  - {"assemble": "<종류>", ...조각} — 잠금화면처럼 합성이 필요한 장면을 조립한다

scenes.card 는 리스트도 받는다 — 카드에 기기를 여러 대 세우는 경우다. 리스트 순서가 좌→우이고
가운데가 히어로다. 세부사항은 풀블리드 한 장이라 리스트를 받지 않는다.
"""

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ai_sheet  # noqa: E402
import lock_screen  # noqa: E402
import status_bar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "snapshot-catalog"
SLOTS = {"card": "s1-card-source", "detail": "s2-detail-source"}
MULTI_SLOTS = {"card"}

ASSEMBLERS = {
    "lock-screen": (lock_screen.compose, ["foremost", "next", "nextRemain", "liveActivity"]),
    "ai-sheet": (ai_sheet.compose, ["background", "sheet"]),
}


def catalog_path(relative):
    path = CATALOG / relative
    if not path.exists():
        raise SystemExit(f"✗ 누락: snapshot-catalog/{relative}")
    return path


def appstore_source(spec, lang):
    path = ROOT / "snapshot-appstore" / lang / spec["file"]
    if not path.exists():
        raise SystemExit(
            f"✗ 누락: snapshot-appstore/{lang}/{spec['file']} — "
            "scripts/capture-appstore-screenshots.sh 로 그 언어를 먼저 촬영해라"
        )
    return path


def assemble(spec, lang):
    kind = spec.get("assemble")
    entry = ASSEMBLERS.get(kind)
    if entry is None:
        raise SystemExit(f"✗ 모르는 assemble 종류: {kind} — 아는 것은 {', '.join(ASSEMBLERS)}")
    compose, keys = entry
    missing = [key for key in keys if not spec.get(key)]
    if missing:
        raise SystemExit(f"✗ {kind} 조립에 {', '.join(missing)} 가 없다 — event.json 을 확인해라")
    return compose(*(resolve(spec[key], lang) for key in keys))


def resolve(spec, lang):
    if isinstance(spec, str):
        return Image.open(catalog_path(spec))
    if not isinstance(spec, dict):
        raise SystemExit(f"✗ 장면 값이 문자열도 객체도 아니다: {spec!r}")
    if spec.get("from") == "snapshot-appstore":
        # 앱 화면 스냅샷은 safe area 없이 콘텐츠만 찍혀 나온다 — 상태창 자리를 여기서 낸다
        with Image.open(appstore_source(spec, lang)) as source:
            return status_bar.inset(source)
    return assemble(spec, lang)


def source_filename(stem, index):
    return f"{stem}.png" if index == 0 else f"{stem}-{index + 1}.png"


def slot_specs(slot, spec):
    if not isinstance(spec, list):
        return [spec]
    if slot not in MULTI_SLOTS:
        raise SystemExit(f"✗ scenes.{slot} 는 리스트를 받지 않는다 — 한 장만 적어라")
    if not spec:
        raise SystemExit(f"✗ scenes.{slot} 가 빈 리스트다")
    return spec


def main(event_id, lang):
    config = json.loads((ROOT / "fastlane" / "in_app_events" / event_id / "event.json").read_text())
    out = ROOT / "snapshot-event" / event_id / lang
    out.mkdir(parents=True, exist_ok=True)

    written = 0
    for slot, stem in SLOTS.items():
        for index, spec in enumerate(slot_specs(slot, config["scenes"][slot])):
            resolve(spec, lang).save(out / source_filename(stem, index))
            written += 1
    print(f"  ✓ [{lang}] {written}장 → snapshot-event/{event_id}/{lang}/")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(sys.argv[1], sys.argv[2])
