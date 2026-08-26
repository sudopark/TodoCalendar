#!/bin/bash
# App Store 업로드용 화면 스크린샷을 언어별로 촬영한다.
#
# usage:
#   scripts/capture-appstore-screenshots.sh <lang> [<lang> ...]
#   scripts/capture-appstore-screenshots.sh --all
#
# 결과: snapshot-appstore/<lang>/<NN-슬러그>.png (gitignore 대상, 언어별 격리)
#       snapshot-appstore/<lang>/widgets/<슬러그>.png — 홈화면 합성 전 위젯 원본
# 03-widgets 는 위젯 원본을 홈화면에 합성해 만드는 별도 단계다 — 여기서는 원본까지만 뽑는다.
#
# capture-guide-screenshots.sh 와 촬영 절차는 같고 세 가지가 다르다:
#   - 6.9" 업로드 규격(1320×2868)이 나오는 iPhone 16 Pro Max 전용 시뮬레이터를 쓴다.
#     가이드 이미지는 iPhone 17(1206×2622)에 맞춰져 있어 시뮬레이터를 공유하면 안 된다
#   - 촬영 후 해상도를 실측해 규격에서 벗어나면 실패로 끊는다
#   - ASC 가 알파 채널이 있는 스샷을 거부하므로 알파를 떨어뜨린다
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMULATOR_NAME='iPhone 16 Pro Max - appstore_ref'
SIMULATOR_DEVICE_TYPE='com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max'
UPLOAD_WIDTH=1320
UPLOAD_HEIGHT=2868

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

# <스킴>|<카탈로그 스위트>|<모듈 디렉토리>
SUITES=(
    "CalendarScenesSnapshots|CalendarScenesCatalogSnapshots|CalendarScenes"
    "EventDetailSceneSnapshots|EventDetailSceneCatalogSnapshots|EventDetailScene"
    "SettingSceneSnapshots|SettingSceneCatalogSnapshots|SettingScene"
    "TodoCalendarAppWidgetSnapshots|WidgetCatalogSnapshots|Widget"
)

# <업로드 파일명>|<모듈 디렉토리>/<스위트>/<캡처 파일명>
MAPPING=(
    "01-calendar|CalendarScenes/CalendarScenesCatalogSnapshots/test_calendar.calendar-light.png"
    "05-repeat-options|EventDetailScene/EventDetailSceneCatalogSnapshots/test_storeRepeatOptions.storeRepeatOptions-light.png"
    "06-event-detail|EventDetailScene/EventDetailSceneCatalogSnapshots/test_eventDetail.eventDetail-light.png"
    "07-event-types|SettingScene/SettingSceneCatalogSnapshots/test_eventTypeList.eventTypeList-light.png"
    "08-appearance|SettingScene/SettingSceneCatalogSnapshots/test_appearanceSetting.appearanceSetting-light.png"
)

# 홈화면 합성 전 위젯 원본 — 화면 규격이 아니라 위젯 캔버스 규격이라 규격 검사·알파 제거 대상이 아니다
WIDGET_MAPPING=(
    "today-and-next|Widget/WidgetCatalogSnapshots/test_widgetTodayAndNext.widget-today-and-next-light.png"
    "event-list|Widget/WidgetCatalogSnapshots/test_widgetEventList.widget-event-list-light.png"
    "today|Widget/WidgetCatalogSnapshots/test_widgetToday.widget-today-light.png"
    "foremost|Widget/WidgetCatalogSnapshots/test_widgetForemost.widget-foremost-light.png"
    "month|Widget/WidgetCatalogSnapshots/test_widgetMonth.widget-month-light.png"
    "ai-command|Widget/WidgetCatalogSnapshots/test_widgetAICommand.widget-ai-command-light.png"
)

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
    if [ -n "$udid" ]; then
        echo "$udid"
        return 0
    fi
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

# 규격 실측 + 알파 제거. 흰/검으로 flatten 하지 않고 채널만 떨어뜨리므로,
# 이미 불투명한지(alpha == 255) 먼저 확인하고 아니면 실패로 끊는다
verify_and_strip_alpha() {
    local python_bin="$1" dir="$2"
    "$python_bin" - "$dir" "$UPLOAD_WIDTH" "$UPLOAD_HEIGHT" <<'PY'
import sys
from pathlib import Path
from PIL import Image

directory, width, height = Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
failures = []
paths = sorted(p for p in directory.glob("*.png"))
for path in paths:
    with Image.open(path) as image:
        if image.size != (width, height):
            failures.append(f"{path.name}: {image.size[0]}x{image.size[1]} — {width}x{height} 아님")
            continue
        if image.mode not in ("RGBA", "LA", "P"):
            continue
        converted = image.convert("RGBA")
        low, _ = converted.getchannel("A").getextrema()
        if low != 255:
            failures.append(f"{path.name}: 투명 픽셀이 있다(alpha 최소 {low}) — 채널만 떨구면 검게 남는다")
            continue
        converted.convert("RGB").save(path)

for path in paths:
    with Image.open(path) as image:
        if image.mode == "RGBA":
            failures.append(f"{path.name}: 알파 채널이 남아 있다")

if failures:
    print("\n".join(f"  ✗ {message}" for message in failures), file=sys.stderr)
    sys.exit(1)
print(f"  ✓ {len(paths)}장 {width}x{height} / 알파 없음")
PY
}

capture_lang() {
    local lang="$1" destination="$2" python_bin="$3" region
    region="$(region_of "$lang")"
    echo "▶︎ [$lang] 촬영 시작 (region=$region)"

    for entry in "${SUITES[@]}"; do
        IFS='|' read -r scheme suite _ <<< "$entry"
        echo "  · $scheme/$suite"
        xcodebuild test \
            -workspace "$ROOT/TodoCalendar.xcworkspace" \
            -scheme "$scheme" \
            -destination "$destination" \
            -only-testing:"$scheme/$suite" \
            -testLanguage "$lang" -testRegion "${lang%%-*}_$region" \
            > "/tmp/capture-appstore-$lang-$scheme.log" 2>&1 \
            || { echo "  ✗ 실패 — /tmp/capture-appstore-$lang-$scheme.log"; return 1; }
    done

    local out="$ROOT/snapshot-appstore/$lang"
    rm -rf "$out"
    mkdir -p "$out/widgets"
    for entry in "${MAPPING[@]}" ; do
        IFS='|' read -r name source <<< "$entry"
        local src="$ROOT/snapshot-catalog/$source"
        [ -f "$src" ] || { echo "  ✗ 누락: $source"; return 1; }
        cp "$src" "$out/$name.png"
    done
    for entry in "${WIDGET_MAPPING[@]}" ; do
        IFS='|' read -r name source <<< "$entry"
        local src="$ROOT/snapshot-catalog/$source"
        [ -f "$src" ] || { echo "  ✗ 누락: $source"; return 1; }
        cp "$src" "$out/widgets/$name.png"
    done
    echo "  ✓ [$lang] ${#MAPPING[@]}장 + 위젯 원본 ${#WIDGET_MAPPING[@]}종 → snapshot-appstore/$lang/"

    verify_and_strip_alpha "$python_bin" "$out" || return 1

    # 검증 스위트 png 가 섞여 들어가지 않았는지 — 섞였다면 -only-testing 이 안 먹은 것이다
    if ! git -C "$ROOT" diff --quiet -- '*__Snapshots__*'; then
        echo "  ⚠︎ [$lang] 커밋 대상 __Snapshots__/ 가 변경됐다. git restore 로 되돌리고 원인을 확인할 것" >&2
        return 1
    fi
}

if [ "${1:-}" = "--all" ]; then
    set -- "${ALL_LANGS[@]}"
fi
[ $# -gt 0 ] || { sed -n '2,12p' "$0"; exit 1; }

PYTHON_BIN="$(python_with_pillow)" || {
    echo "Pillow 를 쓸 수 있는 python3 가 없다 — 알파 제거 단계를 돌릴 수 없다 (pip3 install Pillow)" >&2
    exit 1
}
SIMULATOR_UDID="$(ensure_simulator)"
DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"

failed=()
for lang in "$@"; do
    capture_lang "$lang" "$DESTINATION" "$PYTHON_BIN" || failed+=("$lang")
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "✗ 실패한 언어: ${failed[*]}" >&2
    exit 1
fi
echo "✓ 전체 완료 — $# 개 언어"
