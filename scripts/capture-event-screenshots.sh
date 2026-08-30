#!/bin/bash
# 앱 내 이벤트(In-App Event) 이미지의 소스 장면을 언어별로 촬영한다.
#
# usage:
#   scripts/capture-event-screenshots.sh <event_id> <lang> [<lang> ...]
#   scripts/capture-event-screenshots.sh <event_id> --all
#
# 결과: snapshot-event/<event_id>/<lang>/s1-card-source.png   (카드용 장면)
#       snapshot-event/<event_id>/<lang>/s2-detail-source.png (세부사항용 장면)
#
# capture-appstore-screenshots.sh 와 촬영 절차는 같고 셋이 다르다:
#   - 어느 장면을 뜰지가 스크립트에 없다. fastlane/in_app_events/<event_id>/event.json 의
#     scenes·captureSuites 를 읽는다 — 새 이벤트가 코드 수정 없이 돌아야 한다
#   - 규격 실측을 하지 않는다. 소스 장면은 합성 입력이라 고정 해상도 요구가 없다
#   - 카탈로그 기준 시뮬레이터(iPhone 17)를 쓴다. 앱스토어 스샷 전용기를 공유하지 않는다
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMULATOR_NAME='iPhone 17 - snapshot_ref'
SIMULATOR_DEVICE_TYPE='com.apple.CoreSimulator.SimDeviceType.iPhone-17'

ALL_LANGS=(en ko ja zh-Hans zh-Hant vi th es fr it pt-BR ca de nl sv da nb fi pl cs sk hu ru uk ro el hr tr id ms hi)

region_of() {
    case "$1" in
        en) echo US ;; ko) echo KR ;; ja) echo JP ;;
        zh-Hans) echo CN ;; zh-Hant) echo TW ;;
        vi) echo VN ;; th) echo TH ;; es) echo ES ;; fr) echo FR ;;
        it) echo IT ;; pt-BR) echo BR ;; ca) echo ES ;; de) echo DE ;;
        nl) echo NL ;; sv) echo SE ;; da) echo DK ;; nb) echo NO ;;
        fi) echo FI ;; pl) echo PL ;; cs) echo CZ ;; sk) echo SK ;;
        hu) echo HU ;; ru) echo RU ;; uk) echo UA ;; ro) echo RO ;;
        el) echo GR ;; hr) echo HR ;; tr) echo TR ;; id) echo ID ;;
        ms) echo MY ;; hi) echo IN ;;
        *) echo "region_of: 알 수 없는 언어 $1" >&2; return 1 ;;
    esac
}

# scenes 가 문자열이든 조립형 객체든, 거기 쓰이는 카탈로그 경로를 전부 열거한다
scene_paths() { # <event_id>
    python3 - "$ROOT/fastlane/in_app_events/$1/event.json" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    sys.exit(f"✗ {path} 가 없다 — 이벤트 설정을 먼저 만들어라")
scenes = json.loads(path.read_text()).get("scenes") or {}


def catalog_scenes(spec):
    """스위트 검사 대상인 카탈로그 경로만 — 조각도 같은 형식이라 재귀로 훑는다."""
    if isinstance(spec, list):
        for item in spec:
            yield from catalog_scenes(item)
    elif isinstance(spec, str):
        yield spec
    elif isinstance(spec, dict) and not spec.get("from"):
        # from 은 카탈로그가 아니라 다른 파이프라인 산출물이다 — 검사 대상이 아니다
        for key, value in spec.items():
            if key != "assemble":
                yield from catalog_scenes(value)


for slot in ("card", "detail"):
    spec = scenes.get(slot)
    if not spec:
        sys.exit(f"✗ {path} 에 scenes.{slot} 가 없다")
    for scene in catalog_scenes(spec):
        print(scene)
PY
}

event_config() { # <event_id> <키경로>
    python3 - "$ROOT/fastlane/in_app_events/$1/event.json" "$2" <<'PY'
import json, sys
from pathlib import Path

path, key = Path(sys.argv[1]), sys.argv[2]
if not path.exists():
    sys.exit(f"✗ {path} 가 없다 — 이벤트 설정을 먼저 만들어라")
config = json.loads(path.read_text())
value = config
for part in key.split("."):
    if not isinstance(value, dict) or part not in value:
        sys.exit(f"✗ {path} 에 {key} 가 없다")
    value = value[part]
print("\n".join(value) if isinstance(value, list) else value)
PY
}

latest_ios_runtime() {
    xcrun simctl list runtimes \
        | sed -nE 's/^iOS [0-9.]+ \(([0-9.]+) - [^)]*\) - (com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+)$/\1 \2/p' \
        | sort -k1,1V | tail -1 | cut -d' ' -f2
}

simulator_udid() {
    xcrun simctl list devices available \
        | grep -F "$SIMULATOR_NAME (" | head -1 \
        | sed -E 's/.*\(([0-9A-Fa-f-]{36})\).*/\1/'
}

ensure_simulator() {
    local udid runtime
    udid="$(simulator_udid)"
    if [ -n "$udid" ]; then echo "$udid"; return 0; fi
    runtime="$(latest_ios_runtime)"
    [ -n "$runtime" ] || { echo "설치된 iOS 시뮬레이터 런타임이 없다" >&2; return 1; }
    echo "▶︎ '$SIMULATOR_NAME' 생성 ($runtime)" >&2
    xcrun simctl create "$SIMULATOR_NAME" "$SIMULATOR_DEVICE_TYPE" "$runtime"
}

python_with_pillow() {
    local candidate
    for candidate in python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
        command -v "$candidate" >/dev/null 2>&1 || continue
        "$candidate" -c 'import PIL' >/dev/null 2>&1 && { echo "$candidate"; return 0; }
    done
    return 1
}

# ASC 는 알파 채널이 있는 이미지를 거부한다. 흰/검으로 flatten 하지 않고 채널만 떨어뜨리므로
# 이미 불투명한지 먼저 확인하고 아니면 실패로 끊는다.
strip_alpha() {
    local python_bin="$1" dir="$2"
    "$python_bin" - "$dir" <<'PY'
import sys
from pathlib import Path
from PIL import Image

directory = Path(sys.argv[1])
failures = []
paths = sorted(directory.glob("*.png"))
for path in paths:
    with Image.open(path) as image:
        if image.mode not in ("RGBA", "LA", "P"):
            continue
        converted = image.convert("RGBA")
        low, _ = converted.getchannel("A").getextrema()
        if low != 255:
            failures.append(f"{path.name}: 투명 픽셀이 있다(alpha 최소 {low}) — 채널만 떨구면 검게 남는다")
            continue
        converted.convert("RGB").save(path)

if failures:
    print("\n".join(f"  ✗ {message}" for message in failures), file=sys.stderr)
    sys.exit(1)
print(f"  ✓ {len(paths)}장 / 알파 없음")
PY
}

capture_lang() { # <event_id> <lang> <destination> <python_bin>
    local event_id="$1" lang="$2" destination="$3" python_bin="$4" region
    region="$(region_of "$lang")" || return 1
    echo "▶︎ [$lang] 촬영 시작 (region=$region)"

    local suite
    while IFS= read -r suite; do
        [ -n "$suite" ] || continue
        local scheme="${suite%%|*}" class="${suite##*|}"
        echo "  · $scheme/$class"
        xcodebuild test \
            -workspace "$ROOT/TodoCalendar.xcworkspace" \
            -scheme "$scheme" \
            -destination "$destination" \
            -only-testing:"$scheme/$class" \
            -testLanguage "$lang" -testRegion "${lang%%-*}_$region" \
            > "/tmp/capture-event-$event_id-$lang-$scheme.log" 2>&1 \
            || { echo "  ✗ 실패 — /tmp/capture-event-$event_id-$lang-$scheme.log"; return 1; }
    done <<< "$CAPTURE_SUITES"

    local out="$ROOT/snapshot-event/$event_id/$lang"
    rm -rf "$out" || return 1
    # 단순 복사와 조립(잠금화면 등)을 함께 다룬다
    "$python_bin" "$ROOT/scripts/build_event_sources.py" "$event_id" "$lang" || return 1

    strip_alpha "$python_bin" "$out" || return 1

    # 검증 스위트 png 가 섞여 들어가지 않았는지 — 섞였다면 -only-testing 이 안 먹은 것이다
    if ! git -C "$ROOT" diff --quiet -- '*__Snapshots__*'; then
        echo "  ⚠︎ [$lang] 커밋 대상 __Snapshots__/ 가 변경됐다. git restore 로 되돌리고 원인을 확인할 것" >&2
        return 1
    fi
}

# scenes 가 가리키는 스위트가 captureSuites 에 없으면 이번 실행이 그 장면을 안 찍는다.
# 그래도 snapshot-catalog 에 이전 실행이 남긴 파일이 있으면 조용히 복사돼, 언어도 기기 규격도
# 다른 낡은 이미지가 섞인다. 촬영 전에 끊는다.
ensure_scenes_are_captured() {
    local scene suite_class missing=()
    while IFS= read -r scene; do
        [ -n "$scene" ] || continue
        suite_class="$(echo "$scene" | cut -d/ -f2)"
        grep -qF "|$suite_class" <<< "$CAPTURE_SUITES" || missing+=("$scene (스위트 $suite_class)")
    done <<< "$SCENE_PATHS"
    [ ${#missing[@]} -eq 0 ] && return 0

    {
        echo "✗ captureSuites 가 안 덮는 장면이 있다 — 이번 실행은 이 장면을 찍지 않는다:"
        printf '    %s\n' "${missing[@]}"
        echo "  event.json 의 captureSuites 에 '<스킴>|<스위트클래스>' 를 추가해라"
    } >&2
    return 1
}

[ $# -ge 2 ] || { sed -n '2,10p' "$0"; exit 1; }
EVENT_ID="$1"; shift

SCENE_PATHS="$(scene_paths "$EVENT_ID")"
CAPTURE_SUITES="$(event_config "$EVENT_ID" captureSuites)"
ensure_scenes_are_captured

if [ "${1:-}" = "--all" ]; then set -- "${ALL_LANGS[@]}"; fi

PYTHON_BIN="$(python_with_pillow)" || {
    echo "Pillow 를 쓸 수 있는 python3 가 없다 (pip3 install Pillow)" >&2; exit 1
}
SIMULATOR_UDID="$(ensure_simulator)"
DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"

# capture_lang 을 `|| failed+=(...)` 로 부르면 bash 가 함수 실행 전 구간에서 errexit 을 끈다.
# 종료코드를 따로 받아 판정해야 함수 안의 set -e 가 살아 있다.
failed=()
for lang in "$@"; do
    capture_lang "$EVENT_ID" "$lang" "$DESTINATION" "$PYTHON_BIN"
    status=$?
    [ $status -eq 0 ] || failed+=("$lang")
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "✗ 실패한 언어: ${failed[*]}" >&2
    exit 1
fi
echo "✓ 전체 완료 — $# 개 언어"
