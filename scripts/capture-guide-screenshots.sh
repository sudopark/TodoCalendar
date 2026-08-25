#!/bin/bash
# 서비스 이용 가이드용 화면 스크린샷을 언어별로 촬영한다.
#
# usage:
#   scripts/capture-guide-screenshots.sh <lang> [<lang> ...]
#   scripts/capture-guide-screenshots.sh --all
#
# 결과: snapshot-guide/<lang>/<가이드 파일명>.png (gitignore 대상, 언어별 격리)
# 촬영 후 Terms 레포 guide/images/<lang>/ 로 복사하는 것은 별도 단계다.
#
# app-catalog 스킬 §3 과 규격은 같고 두 가지가 다르다:
#   - -testLanguage/-testRegion 을 언어별로 바꾼다
#   - -only-testing 으로 카탈로그 스위트만 돌린다. 스킴 전체를 돌리면 같은 스킴의 검증
#     스위트(__Snapshots__/ — 커밋 대상)가 그 언어로 재기록돼 워킹트리가 오염된다
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION='platform=iOS Simulator,name=iPhone 17 - snapshot_ref,OS=26.2'

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
    "EventListScenesSnapshots|EventListScenesCatalogSnapshots|EventListScenes"
    "SettingSceneSnapshots|SettingSceneCatalogSnapshots|SettingScene"
    "AIAgentSceneSnapshots|AIAgentSceneCatalogSnapshots|AIAgentScene"
    "TodoCalendarAppWidgetSnapshots|WidgetCatalogSnapshots|Widget"
)

# <가이드 파일명>|<모듈 디렉토리>/<스위트>/<캡처 파일명>
MAPPING=(
    "calendar|CalendarScenes/CalendarScenesCatalogSnapshots/test_calendar.calendar-light.png"
    "event-detail|EventDetailScene/EventDetailSceneCatalogSnapshots/test_eventDetail.eventDetail-light.png"
    "repeat-options|EventDetailScene/EventDetailSceneCatalogSnapshots/test_repeatOptions.repeatOptions-light.png"
    "done-todos|EventListScenes/EventListScenesCatalogSnapshots/test_doneTodos.doneTodos-light.png"
    "settings|SettingScene/SettingSceneCatalogSnapshots/test_settingItemList.settingItemList-light.png"
    "event-type-list|SettingScene/SettingSceneCatalogSnapshots/test_eventTypeList.eventTypeList-light.png"
    "appearance-setting|SettingScene/SettingSceneCatalogSnapshots/test_appearanceSetting.appearanceSetting-light.png"
    "ai-input|AIAgentScene/AIAgentSceneCatalogSnapshots/test_aiInput.aiInput-light.png"
    "ai-result|AIAgentScene/AIAgentSceneCatalogSnapshots/test_aiResult.aiResult-light.png"
    "widget-today-and-next|Widget/WidgetCatalogSnapshots/test_widgetTodayAndNext.widget-today-and-next-light.png"
    "widget-event-list|Widget/WidgetCatalogSnapshots/test_widgetEventList.widget-event-list-light.png"
    "widget-today|Widget/WidgetCatalogSnapshots/test_widgetToday.widget-today-light.png"
    "widget-foremost|Widget/WidgetCatalogSnapshots/test_widgetForemost.widget-foremost-light.png"
    "widget-month|Widget/WidgetCatalogSnapshots/test_widgetMonth.widget-month-light.png"
)

capture_lang() {
    local lang="$1" region
    region="$(region_of "$lang")"
    echo "▶︎ [$lang] 촬영 시작 (region=$region)"

    for entry in "${SUITES[@]}"; do
        IFS='|' read -r scheme suite _ <<< "$entry"
        echo "  · $scheme/$suite"
        xcodebuild test \
            -workspace "$ROOT/TodoCalendar.xcworkspace" \
            -scheme "$scheme" \
            -destination "$DESTINATION" \
            -only-testing:"$scheme/$suite" \
            -testLanguage "$lang" -testRegion "${lang%%-*}_$region" \
            > "/tmp/capture-$lang-$scheme.log" 2>&1 \
            || { echo "  ✗ 실패 — /tmp/capture-$lang-$scheme.log"; return 1; }
    done

    local out="$ROOT/snapshot-guide/$lang"
    mkdir -p "$out"
    for entry in "${MAPPING[@]}"; do
        IFS='|' read -r name source <<< "$entry"
        local src="$ROOT/snapshot-catalog/$source"
        [ -f "$src" ] || { echo "  ✗ 누락: $source"; return 1; }
        cp "$src" "$out/$name.png"
    done
    echo "  ✓ [$lang] ${#MAPPING[@]}장 → snapshot-guide/$lang/"

    # 검증 스위트 png 가 섞여 들어가지 않았는지 — 섞였다면 -only-testing 이 안 먹은 것이다
    if ! git -C "$ROOT" diff --quiet -- '*__Snapshots__*'; then
        echo "  ⚠︎ [$lang] 커밋 대상 __Snapshots__/ 가 변경됐다. git restore 로 되돌리고 원인을 확인할 것" >&2
        return 1
    fi
}

if [ "${1:-}" = "--all" ]; then
    set -- "${ALL_LANGS[@]}"
fi
[ $# -gt 0 ] || { sed -n '2,10p' "$0"; exit 1; }

failed=()
for lang in "$@"; do
    capture_lang "$lang" || failed+=("$lang")
done

if [ ${#failed[@]} -gt 0 ]; then
    echo "✗ 실패한 언어: ${failed[*]}" >&2
    exit 1
fi
echo "✓ 전체 완료 — $# 개 언어"
