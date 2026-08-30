# fastlane/in_app_events/

App Store 앱 내 이벤트(In-App Event)의 원고·설정 자리다. 절차는 `in-app-event` 스킬 소관.

**이 디렉토리의 내용물은 커밋하지 않는다** — 이 README 만 예외다. 원고의 정본은 업로드된 ASC 쪽이고,
여기 파일은 올리기 전 작업 자리다. 다시 손보려면 ASC 콘솔의 현재 값을 보고 채운다.

```
<event_id>/
  event.json
  <ASC 로케일>/name.txt                            # 30자
  <ASC 로케일>/short_description.txt               # 50자
  <ASC 로케일>/long_description.txt                # 120자
  images/<ASC 로케일>/event-card_1920x1080.png     # 합성 산출물
  images/<ASC 로케일>/event-detail_1080x1920.png
```

`<event_id>` 는 사람이 읽는 슬러그다(예: `2026-03-spring`). **ASC 리소스 id 와 다르다** — 스크립트
인자로는 슬러그를 주고, ASC id 는 `event.json` 의 `ascEventId` 에서 읽는다.

로케일 디렉토리 이름은 lproj 가 아니라 **ASC 코드**다 (6개가 다르다 — `../metadata/README.md` 매핑표).

## `event.json`

```json
{
  "ascEventId": "6806709988",
  "badge": "MAJOR_UPDATE",
  "scenes": {
    "card": [
      { "from": "snapshot-appstore", "file": "01-calendar.png" },
      {
        "assemble": "lock-screen",
        "foremost": "Widget/WidgetCatalogSnapshots/test_widgetLockScreenForemost.lockscreen-foremost-dark.png",
        "next": "Widget/WidgetCatalogSnapshots/test_widgetLockScreenNext.lockscreen-next-dark.png",
        "nextRemain": "Widget/WidgetCatalogSnapshots/test_widgetLockScreenNextRemain.lockscreen-next-remain-dark.png",
        "liveActivity": "Widget/WidgetCatalogSnapshots/test_widgetLockScreenLiveActivity.lockscreen-live-activity-dark.png"
      },
      {
        "assemble": "ai-sheet",
        "background": { "from": "snapshot-appstore", "file": "01-calendar.png" },
        "sheet": "AIAgentScene/AIAgentSceneCatalogSnapshots/test_aiResult.aiResult-light.png"
      }
    ],
    "detail": "CalendarScenes/CalendarScenesCatalogSnapshots/test_storeCalendar.storeCalendar-light.png"
  },
  "captureSuites": [
    "TodoCalendarAppWidgetSnapshots|WidgetCatalogSnapshots",
    "AIAgentSceneSnapshots|AIAgentSceneCatalogSnapshots"
  ],
  "style": {
    "backgroundTop": "#2B3A67",
    "backgroundBottom": "#4A5D9B",
    "cardTiltDegrees": 7,
    "cardDeviceHeight": 760,
    "cardFlankScale": 0.8,
    "cardFlankSpread": 0.85
  }
}
```

| 필드 | 읽는 곳 | 필수 | 기본값 |
|---|---|---|---|
| `ascEventId` | `asc-in-app-event.rb` (`push-text`·`push-images`) | ✅ | — |
| `badge` | 사람이 참고 — `set-badge` 는 CLI 인자로 받는다 | ❌ | — |
| `scenes.card` · `scenes.detail` | `capture-event-screenshots.sh`·`build_event_sources.py` | ✅ | — |
| `captureSuites` | `capture-event-screenshots.sh` | ✅ | — |
| `style.backgroundTop` · `backgroundBottom` | `compose-event-images.py` | ✅ | — |
| `style.cardTiltDegrees` | `compose-event-images.py` | ❌ | `7` (허용 5~10) |
| `style.cardDeviceHeight` | `compose-event-images.py` | ❌ | `1100` |
| `style.cardFlankScale` | `compose-event-images.py` | ❌ | `0.8` |
| `style.cardFlankSpread` | `compose-event-images.py` | ❌ | `0.85` |

### 장면 값의 세 형태

`scenes.card`·`scenes.detail` 과 조립 조각은 모두 같은 세 형태를 받는다 (조각도 재귀로 풀린다):

| 형태 | 뜻 |
|---|---|
| `"<Framework>/<스위트클래스>/<파일>"` | `snapshot-catalog/` 기준 상대 경로 |
| `{ "from": "snapshot-appstore", "file": "..." }` | 앱스토어 스샷 파이프라인의 **캡션 얹기 전 원본**. 캡션이 구워진 `fastlane/screenshots/` 는 홍보 문구 금지 조항에 걸려 못 쓴다 |
| `{ "assemble": "<종류>", ...조각 }` | 조각을 합성해 만든다 |

`assemble` 종류와 조각:

| 종류 | 조각 | 결과 |
|---|---|---|
| `lock-screen` | `foremost` · `next` · `nextRemain` · `liveActivity` | 벽지 + 시계 + accessory 위젯 + 라이브 액티비티 |
| `ai-sheet` | `background` · `sheet` | 배경 화면에 딤 30% + 하단 시트 (`showBottomSlide` 와 같은 모양) |

### 카드에 기기 여러 대

`scenes.card` 에 리스트를 주면 그 수만큼 기기가 선다. **리스트 순서가 좌→우이고 가운데가 히어로**다
(원래 크기, 맨 앞에 그려진다). 나머지는 `cardFlankScale` 만큼 작아져 뒤로 물러난다. 세 대가 실용
한계다 — 넷 이상은 `cardFlankSpread` 로 좌우 여백을 못 지킬 수 있고, 그때 합성이 끊긴다.

`scenes.detail` 은 풀블리드 한 장이라 리스트를 받지 않는다.

### 그 밖

- **`captureSuites` 는 카탈로그를 쓰는 장면의 스위트를 다 덮어야 한다** — 안 덮으면 촬영 전에 끊긴다.
  안 끊으면 이전 실행이 남긴 다른 언어·다른 기기 규격 파일이 조용히 복사된다. `from` 형태는
  카탈로그가 아니라 검사 대상이 아니다.
- 앱 화면 스냅샷은 safe area 없이 콘텐츠만 찍혀 나오므로, `from` 으로 불러올 때 상단에 상태창
  자리를 낸다 (`status_bar.inset`). 상태창 자체는 그리지 않는다.
