# SettingScene Framework — CLAUDE.md

## 개요

앱 설정 화면. 외형 설정, 이벤트 기본값, 공휴일, 태그 관리, 피드백 등 설정 관련 Scene들을 포함한다.

---

## Scene 구성

### 전체 화면 플로우

```mermaid
graph TD
    SIL[SettingItemList<br/>설정 메인 메뉴] -->|push| AS[AppearanceSetting<br/>외형 설정]
    SIL -->|push| ES[EventSetting<br/>이벤트 설정]
    SIL -->|push| HL[HolidayList<br/>공휴일 설정]
    SIL -->|push| OSL[OpenSourceLicense<br/>오픈소스 라이선스]
    SIL -->|present| FP[FeedbackPost<br/>피드백]
    SIL -->|push| MA[ManageAccount<br/>MemberScenes]
    SIL -->|bottomSlide| SI[SignIn<br/>MemberScenes]

    AS -->|push| CT[ColorThemeSelect<br/>색상 테마]
    CT -->|push| CTE[ColorThemeEdit<br/>커스텀 테마 편집]
    CT -.->|bottomSlide| CTAG[PaidFeatureAdGuide<br/>BillingScenes 광고 안내]
    CTE -.->|bottomSlide| CTAG
    AS -->|push| WG[WidgetGallery<br/>WidgetScenes]
    AS -->|push| TZ[TimeZoneSelect<br/>타임존]

    ES -->|push| ETS[EventDefaultTagSelect<br/>기본 태그]
    ES -->|push| ENT[NotificationTimeOption<br/>기본 알림 시간]
    ES -->|push| EMA[EventDefaultMapApp<br/>기본 지도 앱]

    HL -->|push| CS[CountrySelect<br/>국가 선택]

    ETL[EventTagList<br/>태그 목록] -->|present| ETD[EventTagDetail<br/>태그 생성/편집]
    ETL -->|push| ES2[EventSetting]
```

---

## Scene 상세

### SettingItemList (설정 메인 메뉴 — 루트)

모든 설정 하위 화면의 진입점. 네비게이션 허브 역할.

| 항목 | 설명 |
|---|---|
| 표시 항목 | 외형, 이벤트 설정, 공휴일, 요금제, 계정, 공유, 피드백 |
| 계정 상태 | 로그인 여부에 따라 "로그인" 또는 "계정 관리" 표시 |
| 요금제 | 로그인 여부와 무관하게 노출. 미로그인이면 탭 시 Paywall 대신 로그인 확인 다이얼로그 → SignIn |

### AppearanceSetting (외형 설정)

3개의 서브 ViewModel로 섹션을 나눈다.

| 서브 VM | 섹션 | 설정 항목 |
|---|---|---|
| `CalendarSectionViewModelImple` | 캘린더 | 시작 요일, 주간 표시 수, 한글 달력 등 |
| `EventOnCalendarViewModelImple` | 캘린더 이벤트 | 태그 색상 표시, 할일 표시 등 |
| `EventListAppearnaceSettingViewModelImple` | 이벤트 목록 | 12/24시 형식 등 |

하위 화면: ColorThemeSelect (커스텀 테마 편집 ColorThemeEdit으로 push, 두 화면 모두 무료 유저에게 BillingScenes 의 공용 광고 안내 시트(`PaidFeatureAdGuideSceneBuilder`)를 띄운다), TimeZoneSelect (leaf), WidgetGallery (WidgetScenes — 위젯 기본 테마 설정을 그 화면 상단이 담는다)

### ColorThemeEdit — 편집 화면 입력 항목

입력은 `CustomColorThemeBuilder` 시드로 들어가 토큰이 된다. 미리보기(`ColorThemeEditPreviewView`)는 편집 중인 초안 색으로 각 토큰이 쓰이는 자리를 칠하고, 입력 행마다 설명이 붙는다. 설명 키 접두는 `setting.appearance.calendar.colorTheme.` 이다.

| 입력 | 들어가는 토큰 | 미리보기에서 칠하는 자리 | 설명 키 |
|---|---|---|---|
| 배경 | `bg0`(=`dayBackground`), 나머지 토큰의 밝기 기준 | 미리보기 카드 바탕 | `edit::background::explain` |
| 강조 | `accent` | "+ 일정" 캡슐 | `edit::accent::explain` |
| 형 | `bg1`·`bg2`·`line` 대비(배경 대비 카드 면) | 일정 카드 면과 구분선 | `edit::form::{filled,grouped,outlined}::explain` — 고른 형을 따른다 |
| 글자 | `text0`(=`weekDayText`)·`text1` | 평일 날짜·일정 제목·시간 | `edit::seed::text::explain` |
| 카드 | `bg1` | 일정 카드 | `edit::seed::surface::explain` |
| 오늘 | `todayBackground` | 3일 칸 | `edit::seed::today::explain` |
| 선택일 | `selectedDayBackground`(글자 `selectedDayText` 는 대비로 정한다) | 9일 칸 | `edit::seed::selectedDay::explain` |
| 휴일·주말 | `holidayOrWeekEndWithAccent` | 일·토요일과 공휴일 날짜 글자 | `edit::seed::holidayOrWeekEnd::explain` |
| AI | `accentAI` | AI 캡슐 | `edit::seed::ai::explain` |

휴일·주말 글자는 강조 요일 설정과 무관하게 칠한다 — 설정이 꺼져 있어도 그 입력이 칠하는 자리가 보여야 한다.

### EventSetting (이벤트 기본값)

| 항목 | 설명 |
|---|---|
| 기본 태그 | EventDefaultTagSelect로 선택 |
| 기본 알림 시간 | 일반 이벤트 / 하루종일 이벤트 각각 설정 |
| 기본 지도 앱 | EventDefaultMapApp으로 선택 |

### HolidayList + CountrySelect (공휴일)

```mermaid
graph LR
    HL[HolidayList<br/>공휴일 목록] -->|push| CS[CountrySelect<br/>국가 선택]
    CS -->|선택 후 pop| HL
```

### EventTagList + EventTagDetail (태그 관리)

```mermaid
sequenceDiagram
    participant ETL as EventTagList
    participant ETD as EventTagDetail

    ETL->>ETD: present (새 태그 / 편집)
    ETD-->>ETL: Listener 콜백
    Note over ETD,ETL: eventTag(created:) / eventTag(updated:) / eventTag(deleted:)
```

| 항목 | 설명 |
|---|---|
| EventTagList | 커스텀 + 외부 캘린더 태그 목록, 보이기/숨기기 토글 |
| EventTagDetail | 태그 이름/색상 편집, 삭제 |
| Listener | `EventTagDetailSceneListener` — created/updated/deleted 콜백 |
| `isRootNavigation` | true면 모달 dismiss, false면 nav pop |

### OpenSourceLicense (오픈소스 라이선스)

| 항목 | 설명 |
|---|---|
| 표시 방식 | push (leaf) |
| 데이터 | `Resources/open-source-licenses.json` — `Bundle.module`로 로드. 라이브러리 30개 메타 + 라이선스 종류별 전문 6부 |
| 화면 구성 | 라이브러리 목록(이름·저작권·라이선스명, 탭하면 소스 저장소를 사파리로) + 하단에 종류별 전문 |
| 갱신 | SPM 의존성이 바뀌면 JSON을 손으로 갱신 |

### FeedbackPost (피드백)

| 항목 | 설명 |
|---|---|
| 표시 방식 | present (모달) |
| 역할 | 사용자 피드백/버그 리포트 전송 |
| 라우팅 | 없음 (leaf) |

---

## Listener 프로토콜

```mermaid
graph TD
    ETDL[EventTagDetailSceneListener] -->|상속| ETLL[EventTagListSceneListener]
    ETDL -->|conform| ETD_VM[EventTagDetailViewModelImple]
    ETLL -->|conform| ETL_VM[EventTagListViewModelImple]
    ETDL -->|conform| SET_VM[SelectEventTagViewModelImple<br/>EventDetailScene]
```

`EventTagDetailSceneListener`는 SettingScene 내부뿐 아니라 EventDetailScene의 SelectEventTag에서도 사용된다.

---

## Builder 조립

```mermaid
graph TD
    SSB[SettingSceneBuilderImple] -->|생성| SIL[SettingItemListBuilder]
    SSB -->|생성| ASB[AppearanceSettingBuilder]
    SSB -->|생성| ESB[EventSettingBuilder]
    SSB -->|생성| ETLB[EventTagListBuilder]
    SSB -->|생성| ETDB[EventTagDetailBuilder]
    SSB -->|생성| HLB[HolidayListBuilder]
    SSB -->|생성| FPB[FeedbackPostBuilder]
    SSB -->|생성| OSLB[OpenSourceLicenseBuilder]

    ASB -->|하위| CTB[ColorThemeSelectBuilder]
    CTB -->|하위| CTEB[ColorThemeEditBuilder]
    ASB -->|주입받음| WGB[WidgetGallerySceneBuilder<br/>구현체는 WidgetScenes]
    ASB -->|하위| TZB[TimeZoneSelectBuilder]

    ESB -->|하위| ETSB[EventDefaultTagSelectBuilder]
    ESB -->|하위| ENTB[NotificationTimeBuilder]
    ESB -->|하위| EMAB[EventDefaultMapAppBuilder]

    HLB -->|하위| CSB[CountrySelectBuilder]
```

---

## 프레임워크 내부 공용 컴포넌트

전용 공용 폴더 없이 기능 하위폴더끼리 교차 참조 중 — 새 공용 뷰 추가 시 rules §2 배치 규칙(전용 폴더) 따를 것.

| 컴포넌트 | 위치 | 역할 | 사용처 |
|---|---|---|---|
| `CalendarAppearanceSampleView` | `Setting/Appearance/CalendarSection/CalendarAppearancePreviewView.swift` | 설정 미리보기용 미니 월간 캘린더 샘플. 색 세트를 주입하면 그 색으로 칠한다 | CalendarAppearancePreviewView, ColorThemeSelectView |
| `ColorThemePreviewView` / `ColorThemeItemView` | `Setting/Appearance/ColorTheme/ColorThemePreviewView.swift` | 색 테마 미리보기 / 선택 아이템 셀. 모델은 `ColorThemeModel` 프로토콜(`BuiltInColorThemeModel`·`CustomColorThemeModel`) | ColorTheme 내부 + CalendarAppearancePreviewView |

---

## 외부 의존성

| 방향 | 대상 | 용도 |
|---|---|---|
| → | MemberScenes | 로그인/계정 관리 (MemberSceneBuilder) |
| → | `Scenes.WidgetGallerySceneBuilder` | 위젯 갤러리 (구현체는 WidgetScenes — 앱 루트가 `SettingSceneBuilderImple` 에 주입) |
| ← | TodoCalendarApp | ApplicationRootBuilder에서 생성 |
| ← | EventDetailScene | SelectEventTag에서 태그 관리 화면 사용 (SettingSceneBuilder) |
