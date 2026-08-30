# TodoCalendar 제품 기획서

> 코드베이스 기반 기능/정책 명세. 최종 갱신: 2026-08-30 (3.0.0 기준 — AI 에이전트·과금·Apple 캘린더·Live Activity 반영)
>
> 각 섹션의 상세 스펙은 `spec/` 하위 파일을 참조.
>
> 섹션 번호는 `spec/*` 문서들이 역참조하므로 재배열하지 않는다. 새 영역은 뒤에 이어 붙인다.

---

## 1. 앱 개요

| 항목 | 내용 |
|---|---|
| 플랫폼 | iOS 17+ |
| 아키텍처 | 오프라인 우선 (Offline-First), MVVM + Router + Builder |
| UI | SwiftUI + UIKit 하이브리드 |
| 빌드 | Tuist v4, Swift 6.0, 전 프레임워크 static |
| 확장 타겟 | Widget(위젯·Control Widget·Live Activity), Share(공유 시트), IntentExtensions(위젯 설정 intent) |
| App Scheme | `tc.app://` |

**핵심 가치**: 캘린더와 할일을 하나의 앱에서 통합 관리. 로그인 없이도 모든 핵심 기능 사용 가능하며, 로그인 시 클라우드 동기화·AI 입력 제공.

**로그인이 필요한 기능**: 서버 동기화, AI 입력, 플랜 구매. 그 외 이벤트 생성·수정·반복·알림·위젯·외부 캘린더는 비로그인에서도 동작한다.

---

## 2. 화면 구성

> **상세 스펙**: [spec/screens.md](spec/screens.md) — 캘린더 그리드 정렬 알고리즘, 모드별 필드 매트릭스, 저장 조건, 필드 연동, 에러 표시 패턴

### 2.1 메인 캘린더
- 월별 캘린더 그리드 (좌우 스와이프 무한 페이징, 3개월 윈도우)
- 이벤트 색상 바 표시 + "+N 더보기" 인디케이터
- 일별 이벤트 목록 (강조 이벤트, 미완료 할일, 이벤트, 빠른 입력)
- 이벤트 정렬: 시간 없는 할일 → 시간 있는 할일 → 일정 → 공휴일 → 외부 캘린더 이벤트

### 2.2 이벤트 상세
- 모드: 생성(Add), 할일 수정, 일정 수정, 공휴일, 구글 캘린더, Apple 캘린더, 완료 할일
- 모드별 필드 활성/비활성/숨김 매트릭스
- 저장 조건: 할일=이름 필수, 일정=이름+시간 필수
- 필드 연동: 하루종일 토글 시 알림 초기화, 시간 미선택 시 반복/알림 불가
- 추가 액션: 삭제, 복사, 타입 변환(할일↔일정), 강조 토글

### 2.3 완료 할일 목록
- 완료 날짜 기준 그룹핑 (오늘/어제/이번 달/월별/연별)
- 커서 기반 무한 스크롤 페이지네이션
- 완료 취소 (목록에서 직접 / 상세에서)
- 일괄 삭제: 전체/1개월/3개월/6개월/1년 이전

### 2.4 설정
```
설정
├── 계정 (로그인/계정 관리)
├── 플랜 (paywall 진입)
├── 외형 설정 (캘린더 외형, 컬러 테마, 타임존, 위젯 외형)
├── 이벤트 설정 (기본 태그, 기본 알림, 기본 지도 앱)
├── 공휴일 설정 (국가 선택)
├── AI로 추가 안내 (Siri·위젯) / 웹에서 열기
├── 피드백 전송
├── 광고 개인정보 옵션
└── 도움말 / 앱 공유 / 리뷰 / 약관 / 개인정보처리방침 / 오픈소스 라이선스 / 소스코드
```

### 2.5 인증
- 로그인: 바텀시트 모달, 구글/애플 OAuth2
- 계정 관리: 로그아웃, 계정 삭제, 데이터 마이그레이션

---

## 3. 이벤트 모델

### 3.1 할일 (TodoEvent)

> **상세 스펙**: [spec/todo-event.md](spec/todo-event.md) — 유효성 검증, 완료/수정/삭제 상태 전이, 조회 필터링

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 고유 식별자 (자동 생성) |
| name | String | 이벤트 이름 (**유일한 필수값**) |
| time | EventTime? | 시간 (없으면 "현재 할일") |
| repeating | EventRepeating? | 반복 설정 |
| repeatingTurn | Int? | 현재 반복 회차 (nil = turn 1) |
| eventTagId | EventTagId? | 태그/색상 |
| notificationOptions | [EventNotificationTimeOption] | 알림 시간 목록 |

**완료 처리**: 원본 삭제 → DoneTodoEvent 생성. 반복이면 다음 회차 새 인스턴스 추가.
**수정 방식**: `.put`(전체 교체) / `.patch`(부분 수정)
**반복 수정 범위**: `.all`(전체) / `.onlyThisTime`(새 할일 + 원본 전진)

### 3.2 일정 (ScheduleEvent)

> **상세 스펙**: [spec/schedule-event.md](spec/schedule-event.md) — 3가지 수정 범위 상세, 캐시 시스템, 제외 목록

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 고유 식별자 (자동 생성) |
| name | String | 이벤트 이름 (**필수**) |
| time | EventTime | 시간 (**필수** — 할일과 다름) |
| repeating | EventRepeating? | 반복 설정 |
| repeatingTimeToExcludes | Set\<String\> | 제외된 반복 시간 |

**수정 범위 (3가지)**:
- `.all`: 전체 시리즈 수정
- `.onlyThisTime`: 해당 시간 제외 + 새 단독 이벤트
- `.fromNow`: 원본 종료 + 새 시리즈 시작

### 3.3 EventTime (시간 표현)

| 형태 | 설명 |
|---|---|
| `.at(TimeInterval)` | 특정 시점 |
| `.period(Range<TimeInterval>)` | 시작~종료 기간 |
| `.allDay(Range<TimeInterval>, secondsFromGMT)` | 하루종일 + 타임존 오프셋 |

### 3.4 DoneTodoEvent (완료 할일)

원본 할일 정보(이름, 태그, 시간, 알림)를 복사하여 생성. `originEventId`로 원본 참조. 되돌리기 가능.

### 3.5 이벤트 상세 데이터 (EventDetailData)

모든 이벤트에 공통 첨부 가능: 장소(이름+좌표+주소), URL, 메모.

---

## 4. 반복 이벤트

> **상세 스펙**: [spec/repeating-events.md](spec/repeating-events.md) — 옵션별 파라미터 제약, 계산 알고리즘, 겹침 판정, turn 생명주기

### 반복 옵션 (6가지)

| 옵션 | 파라미터 | 타임존 |
|---|---|---|
| 매일 | interval: 1~999일 | 불필요 |
| 매주 | interval: 1~5주, 요일 선택 | 필수 |
| 매월 | interval: 1~11개월, 일자 또는 N번째 요일 | 필수 |
| 매년 | interval: 1~99년, 월+요일 서수 | 필수 |
| 매년 특정일 | 고정 월/일 | 필수 |
| 음력 매년 | 음력 월/일, interval 고정 1 | 필수 |

### 종료 조건

없음(무한) / `.until(시점)` / `.count(N회)` — 상호 배타적

### Turn 규칙

- turn 1부터 시작, 완료/수정/삭제/건너뛰기마다 +1
- 건너뛰기도 count에서 turn 소비

---

## 5. 이벤트 태그

> **상세 스펙**: [spec/tags-foremost-notifications.md](spec/tags-foremost-notifications.md) — 태그 CRUD 상세, 색상 결정 체계, 보이기/숨기기 영향 매트릭스, 자동 새로고침

| 태그 유형 | 식별자 | 기본 상태 |
|---|---|---|
| 기본 (default) | `.default` | 시스템 |
| 공휴일 (holiday) | `.holiday` | 시스템 |
| 커스텀 | `.custom(uuid)` | 생성 시 보임 |
| 외부 캘린더 | `.externalCalendar(serviceId, id)` | 연동 시 숨김 |

- 커스텀 태그: 이름 + 색상(hex)으로 생성/수정/삭제
- 태그 삭제 시 관련 이벤트 일괄 삭제 옵션 (cascade)
- 캘린더에서 태그별 보이기/숨기기 토글 (`offEventTagIdsOnCalendar`, 역논리)
- 색상: default/holiday는 설정값, custom은 태그 자체, 구글은 `GoogleCalendarEventColorSource`, Apple은 `AppleCalendarEventColorSource`

---

## 6. 강조 이벤트 (Foremost Event)

> **상세 스펙**: [spec/tags-foremost-notifications.md](spec/tags-foremost-notifications.md) — 상태 전이, Publisher 체인, 위젯 연동, 엣지 케이스, API 엔드포인트

사용자가 가장 중요한 이벤트 **1개**를 지정.

- `ForemostEventId`: eventId + isTodo 플래그로 식별
- 캘린더 일별 목록 상단 고정 표시
- 위젯에서 강조 노출 (`ForemostEventWidget`)
- 지정/해제 시 상태: idle → marking/unmarking → idle (defer로 복원 보장)
- 위젯에서 할일 완료 토글 가능 (`TodoToggleIntent`)
- 이벤트 삭제 시 graceful degradation (nil 반환)

---

## 7. 알림

> **상세 스펙**: [spec/tags-foremost-notifications.md](spec/tags-foremost-notifications.md) — fire date 계산, 타임존 처리, 반복 이벤트 알림, 라이프사이클, ID 관리, FCM 푸시

### 알림 시간 옵션

| 시간 이벤트 (11개) | 하루종일 이벤트 (5개) |
|---|---|
| 정시, 1분/5분/10분/15분/30분/1시간/2시간/1일/2일/7일 전 | 당일 9시/12시, 1일/2일/7일 전 9시 |

커스텀: `DateComponents`로 자유 지정

### 알림 정책

- 이벤트당 **복수** 알림 설정 가능
- 기본 알림: 시간/하루종일 별도 설정 (UserDefaults 저장)
- 로컬 알림 범위: 향후 365일, 반복 이벤트는 각 인스턴스마다 개별 생성
- 이벤트 변경 시: 기존 알림 전부 취소 → 새 알림 등록 (DB에 eventId ↔ notificationId 매핑)
- FCM 푸시: 로그인 시 토큰 등록 (PUT /notification), 중복 등록 방지

---

## 8. 구글 캘린더 연동

> **상세 스펙**: [spec/google-calendar.md](spec/google-calendar.md) — OAuth 상세, 다중 계정 Pool 아키텍처, 연동/해제 플로우, DB 스키마, 캐시 전략, 에러 처리
>
> Apple 캘린더는 자격·다중계정·쓰기 방식이 달라 별도 섹션이다 — [§23](#23-apple-캘린더-연동)

- 최초 연동은 **읽기 전용** scope, 다중 계정 동시 지원, Google OAuth2
- 쓰기(이벤트 수정·삭제)는 `readWrite` scope 승격이 필요하다. 승격 전에는 `EventWritePermission.needReauthentication`으로 갈려 재인증을 유도하고, 읽기 전용 캘린더는 `.readOnlyCalendar`
- 연동: OAuth → 자격증명 저장(Keychain) → DB 연결(참조 카운팅) → 색상/캘린더/이벤트 동기화
- 해제: 자격증명 삭제 → DB 해제 → SharedDataStore 정리 → 태그 off 정리
- 캘린더별 보이기/숨기기 (기본 숨김, 사용자 활성화)
- 이벤트 상세: 참석자, 회의 링크, 첨부파일, 상태(확정/미정/취소) — "구글에서 편집" 링크
- 토큰 자동 갱신 (Alamofire AuthenticationInterceptor), 갱신 실패 시 재인증

---

## 9. 위젯 (19종 + Control Widget 1종)

> **상세 스펙**: [spec/widgets.md](spec/widgets.md) — 위젯별 사이즈 매트릭스, Timeline 갱신 정책, Intent 파라미터, 데이터 소스, App Group 공유, 딥링크 URL, 캐시 메커니즘

| 분류 | 위젯 |
|---|---|
| 기본 (8) | TodayAndNext, Today, NextEvent, NextRemainEvent, ForemostEvent, Month, EventList, AICommandShortcut |
| 주/월 (7) | 1~4주, 이번달/지난달/다음달 |
| 조합 (4) | TodayAndMonth, EventAndMonth, EventAndForemost, DoubleMonth |
| Control (1, iOS 18+) | AICommandControl — 제어 센터에서 AI 입력 진입 |

`DDayWidget`은 #741로 배포 보류 중이다. 갤러리 노출은 `TodoCalendarWidgetBundle`에서 주석으로 막혀 있고(`@WidgetBundleBuilder`가 런타임 조건을 못 받는다), 앱 쪽 후보 등록 메뉴는 `FeatureFlag.ddayWidget`이 가린다. 재개할 땐 **둘 다** 되살려야 한다.

- `TodoToggleIntent`: 위젯에서 할일 완료 토글 (SQLite 직접 쓰기 + 캐시 리셋)
- `EventTypeSelectIntent`: 태그 기반 위젯 필터링 (커스텀+외부 캘린더 태그 지원)
- 딥링크: 위젯 탭 → `tc.app://calendar/event/{type}?event_id=...`
- Timeline 갱신: 다음 날 00:00 또는 1시간 후 (가까운 쪽), 앱 백그라운드 시 전체 리로드
- 위젯 외형: 배경 `.system` 또는 `.custom(hex)` (밝기 기반 ColorSet 자동 전환)

---

## 10. 계정 & 인증

> **상세 스펙**: [spec/account-auth.md](spec/account-auth.md) — OAuth2 플로우, Factory 전환 영향 매트릭스, DB 분리, 마이그레이션

- 오프라인 모드 (비로그인): 로컬 DB만, 모든 핵심 기능 사용 가능
- 구글/애플 로그인: OAuth2 → Firebase Auth → 서버 동기화 활성화
- 로그인 시: UseCase Factory 전환 (NonLogin → Login), 사용자별 DB 생성
- 로그아웃/삭제: Factory 역전환, SharedDataStore 초기화
- 데이터 마이그레이션: 비로그인 로컬 데이터 → 클라우드 업로드 (태그→할일→일정→상세→완료 순)

---

## 11. 동기화

> **상세 스펙**: [spec/sync.md](spec/sync.md) — 오프라인 큐 테이블, API 엔드포인트, 충돌 해결, 백그라운드 동기화

- **오프라인 우선**: 로컬 즉시 저장 → 오프라인 큐 → 백그라운드 업로드
- 서버 동기화: EventTag/Todo/Schedule, 타임스탬프 기반 증분, 30건/페이지
- 오프라인 큐: SQLite 테이블, 최대 10회 재시도, FIFO
- 충돌 해결: **서버 우선 (Last-Write-Wins)**
- 백그라운드: `BGAppRefreshTask`, ~매시간, 완료 후 위젯 갱신
- 강제 동기화: 타임스탬프 초기화 → 전체 재동기화

---

## 12. 설정

> **상세 스펙**: [spec/settings.md](spec/settings.md) — UserDefaults 키, 기본값, 영향받는 화면 매트릭스

### 캘린더 외형
- 첫째 요일, 행 높이, 이벤트 텍스트 크기/볼드, 태그 색상 표시
- 공휴일/음력 표시, 12/24시간, 미완료 할일 상단, 햅틱/애니메이션

### 이벤트 기본값
- 기본 길이(0분~하루종일), 기본 태그, 기본 알림(시간/하루종일), 기본 지도 앱

### 공휴일
- 국가 선택 (디바이스 지역 자동), 연도별 lazy 로딩, 월 경계 로딩

### 타임존/테마/태그 색상
- 타임존: 시스템 기본, 전체 목록에서 선택
- 컬러 테마: systemTheme, defaultLight, defaultDark
- 기본 태그 색상: default=`#088CDA`, holiday=`#D6236A`

---

## 13~19. 인프라 & 기타

> **상세 스펙**: [spec/infrastructure.md](spec/infrastructure.md) — SharedDataStore, 딥링크, 피드백, D-Day, DB 마이그레이션, 외부 의존성

### SharedDataStore
- 모든 Usecase가 싱글톤으로 상태 공유, Combine 실시간 전파
- `NSRecursiveLock` 스레드 안전, 키별 lazy Subject
- 로그인/로그아웃 시 조건부 초기화

### 딥링크
- `tc.app://calendar/?select=YYYY_MM_DD` (날짜 이동)
- `tc.app://calendar/event/?id=...&type=...` (이벤트 상세)
- 미초기화 시 대기 큐 보관

### 미완료 할일 정책

> **상세 스펙**: [spec/uncompleted-todos.md](spec/uncompleted-todos.md)

- 정의: `time.upperBoundWithFixed <= 현재시각` (기한 초과)
- 시간 없는 할일 = 제외, 미래 할일 = 제외
- 생성/수정/완료/삭제/건너뛰기 시 자동 갱신

### D-Day 카운트다운
- 타임존 인지 일수 계산, 1초 타이머 실시간 업데이트

### DB 마이그레이션
- 메인 DB v7. 외부 캘린더 DB는 서비스별로 따로 센다 — Google v1, Apple v0
- `AppEnvironment.dbVersion` + `Table.migrateStatement` + `AppDataMigrationImple` 스텝, 세 위치 동시 변경 필수

### 외부 의존성
- 네트워크·데이터: Alamofire, SQLiteService, Kingfisher, Pulse
- 인증·백엔드: Firebase(Messaging·Analytics), GoogleSignIn, AppAuth, keychain-swift
- 함수형·리액티브: swift-prelude(Prelude/Optics), CombineExt, CombineCocoa, publisher-async-bind, swift-async-algorithms
- 광고: Google Mobile Ads (+ User Messaging Platform)
- 기타: SwiftLinkPreview, Toaster / 테스트: swift-snapshot-testing
- 시스템 프레임워크: StoreKit 2, EventKit, Speech, Vision, WidgetKit, ActivityKit, AppIntents
- Tuist v4 + SPM, **static framework**

---

## 20. 버전 호환성 / 업데이트 체크

> **상세 스펙**: [spec/infrastructure.md §7](spec/infrastructure.md) — 판정 알고리즘, 버전 비교, 팝업 연출, 트리거 시점

서버 API 브레이킹 체인지나 치명적 결함 발견 시 구버전 사용자를 새 버전으로 유도하고, 가벼운 안내는 "권장" 수준으로 내리는 채널.

### 20.1 구성

- **원격 설정 소스**: `app-config/update-info.json` — GitHub raw URL로 서빙 (앱 재배포 없이 조건만 갱신)
  ```json
  {
    "force_update_version": "2.0.0",
    "recommend_update_version": "1.9.0"
  }
  ```
- **체크 트리거**: 앱 시작 + 포그라운드 복귀 (`willEnterForegroundNotification`)
- **판정 결과** (`AppUpdateRequirement` 이넘):
  - `forceRequired` — 현재 버전이 `force_update_version` 미만
  - `recommended` — force는 통과했지만 `recommend_update_version` 미만
  - "업데이트 불필요"는 방출 없음 (정상 상태는 nil)

### 20.2 버전 비교

`major.minor.patch` 포맷을 자리수별 zero-padding 후 `.numeric` 옵션으로 비교 — `1.10 > 1.9`, `2.0 == 2.0.0` 모두 정확. semver pre-release(`1.0-beta`) 표기는 비대응.

### 20.3 UI 동작

| 요구 | 팝업 | 닫기 | dismiss 스와이프 | "업데이트" 동작 |
|---|---|---|---|---|
| forceRequired | `UpdatePopupView` (`.forceRequired`) | 버튼 없음 | 차단 (`isModalInPresentation=true`) | App Store 이동, 팝업 유지 |
| recommended | `UpdatePopupView` (`.recommended`) | "나중에" 버튼 | 차단 (force와 동일 설정) | App Store 이동 + 팝업 닫힘 |

- 루트 레벨 팝업: `ApplicationRootRouter.showUpdatePopup(_:)`이 `UIHostingController`를 `overFullScreen`으로 present.
- 중복 노출 방지: Router가 현재 팝업 VC 참조(`updatePopupViewController`)를 보관하고 nil일 때만 새로 present.

### 20.4 한계 / 후속 과제

- `.recommended`는 포그라운드 복귀마다 재노출됨. "나중에" 선택 후 일정 기간 억제 정책은 미구현 (필요 시 마지막 dismiss 시점 로컬 저장).
- 버전 비교는 순수 숫자 포맷만 가정. semver pre-release는 별도 대응 필요.

---

## 21. AI 에이전트

> **상세 스펙**: [spec/ai-agent.md](spec/ai-agent.md) — Command/Job/Mutation 구분, 상태 머신, 폴링·푸시 추적, 확인 플로우, 사용량 판정

자연어 지시를 서버가 해석해 이벤트를 만들고·고치고·지운다. **로그인 필수**.

- 입력 수단 3가지: 음성(Speech), 키보드, 이미지(Vision OCR)
- 상태: `idle → listening(방식) → processing → done / confirm / failed`
- 지우거나 바꾸는 작업은 서버가 `CONFIRM`으로 멈추고 사용자 승인을 기다린다. 승인 토큰(JWT)의 `exp`로 만료를 판정하되 서명 검증은 하지 않는다 (UI 판정 전용)
- job 추적은 **10초 폴링 + FCM 푸시** 두 갈래를 merge. 총 10분 타임아웃
- job 결과의 mutation 중 `todo`·`schedule`·`tag`가 하나라도 있으면 이벤트 재동기화. `doneTodo`·`eventDetail`은 트리거하지 않는다
- 사용량은 플랜별 일일 한도(UTC 자정 리셋) + top-up 잔량. **둘은 합산하지 않는다** — top-up 잔량은 이미 차감된 값이다
- 한도 소진 상태로 입력에 진입하면 paywall로 넘어간다

### 앱 밖 진입점

| 진입점 | 구현 |
|---|---|
| Siri · 단축어 | `SendAICommandIntent` (앱을 열지 않음) |
| 액션 버튼 · 홈 화면 | `OpenAICommandInputIntent` |
| 위젯 | `AICommandShortcutWidget` |
| 제어 센터 (iOS 18+) | `AICommandControlWidget` |
| 공유 시트 | `TodoCalendarAppShare` 확장 |

이 경로로 만든 job은 앱 메모리에 없다. 포그라운드 복귀 시 로컬에 저장된 `ProcessingAICommand`로 추적을 이어받는다.

---

## 22. 과금 & 광고

> **상세 스펙**: [spec/billing.md](spec/billing.md) — 플랜·top-up 모델, 구매·복원 순서 제약, paywall 상태, 광고 노출 판정

### 플랜

`free < standard < lifetime`. `BillingPlanId.covers(_:)`는 **등급 커버 판정**이지 일치 판정이 아니다.

- 플랜 카탈로그(`GET /v1/billing/plans`)에 **가격은 없다** — 현지화 가격은 StoreKit이 답한다
- 현재 발효 플랜(`BillingUserPlan`)은 `GET /v1/ai/usage`의 plan 필드와 구매 응답이 같은 스키마로 내려준다. 화면이 믿을 것은 `SharedDataStore`의 `billingUserPlan` 하나
- 하향은 즉시 적용이 아니라 `scheduledChange`(적용 시각 동반) 예약
- top-up은 `credits × (1 + bonusRate)`만큼 적립

### 구매 순서 제약

- `appAccountToken`을 **결제 전에** 확보한다. 없으면 결제창을 띄우지 않는다 — 주인을 표시할 값이 없는 트랜잭션은 서버가 거절한다
- `finishTransaction`은 **서버 반영 성공 후에만** 부른다. 먼저 부르면 실패 시 영수증이 사라져 복구 불가
- 유저 취소·승인 대기(Ask to Buy)는 에러가 아니라 별도 결과값
- 복원·앱 밖 갱신·환불·가족 공유는 `Transaction.updates` 스트림으로 들어와 `POST /v1/billing/transactions`로 반영된다

### Paywall 진입점

| 위치 | 구매 후 닫힘 |
|---|---|
| 설정 > 플랜 | ✗ |
| AI 크레딧 소진 | ✓ |

구독 화면의 법적 고지(기간·자동 갱신·해지 경로·약관 링크)는 축약하면 심사에서 리젝된다.

### 광고

무료 플랜에만 노출한다 (`planId == .free` **일치** 판정 — `covers` 아님).

- 배너: 유료 전환 시 배너가 차지하던 하단 자리까지 걷는다
- 전면: scope별 하루 1회. 앱 시작 트리거는 추가로 "오늘 첫 콜드런치 + 누적 10회 이상 + 최초 실행 후 7일 경과"를 모두 만족해야 한다

---

## 23. Apple 캘린더 연동

> **상세 스펙**: [spec/apple-calendar.md](spec/apple-calendar.md) — 권한 상태별 분기, 캐시 우선 조회, RRULE 변환, 쓰기 범위

기기의 EventKit 캘린더를 앱 달력에 합산한다. Google과 같은 External Calendar context지만 자격·계정·쓰기 방식이 다르다.

| | Google | Apple |
|---|---|---|
| 자격 | OAuth2 토큰 (Keychain) | 기기 권한 (EventKit) |
| 계정 | 다중 (accountId별 Pool) | 단일 |
| 쓰기 | `readWrite` scope 재인증 필요 | `fullAccess` 권한이면 바로 |

- 권한 분기: `fullAccess` 즉시 성공 / `denied`·`writeOnly` 승격 실패는 설정 이동 유도 / `restricted`는 지원 불가 안내 / `notDetermined`는 시스템 요청 후 재확인
- 캘린더 하나 = 태그 하나(`.externalCalendar`), 기본 숨김. 색은 캘린더 색을 그대로 쓴다
- 조회는 **캐시 먼저 방출 → EventKit 재조회 후 다시 방출**. 상세는 원본 이벤트와 병합해 반복 규칙·참석자를 채운다
- 쓰기 범위는 `thisEventOnly` / `thisAndFuture`. 반복은 RRULE 문자열로 다루고 EventKit 경계에서만 `EKRecurrenceRule`로 변환한다
- 캘린더별 쓰기 가능 여부는 3-state다 — `nil`은 "아직 판정 불가"이고 `false`로 뭉개면 안 된다
- 위젯용 구현체는 DB 캐시에서만 읽고 쓰기는 지원하지 않는다

---

## 24. Live Activity (이벤트 카운트다운)

곧 시작하는 이벤트 하나를 잠금화면과 다이나믹 아일랜드에 카운트다운으로 띄운다. **동시에 하나만** 등록된다.

### 대상 (`LiveActivityTarget`)

`todo` / `schedule(turnKey)` / `holiday` / `googleCalendar` / `appleCalendar` — 앱이 다루는 모든 이벤트 종류를 대상으로 삼을 수 있다.

### 등록 조건 (`EventLiveActivityStartFailReason`)

| 실패 | 조건 |
|---|---|
| `eventNotFound` | 대상 이벤트를 못 찾음 |
| `alreadyPassed` | 이벤트 시각이 이미 지남 |
| `tooFarFuture` | 이벤트 시각이 현재로부터 **8시간**을 넘음 |

### 동작

- 앱 시작·포그라운드 복귀 시 등록 상태를 복원하고, 만료된 활동은 종료한다
- 원본 이벤트가 바뀌면(이름·시간·삭제) 활동 내용도 따라 갱신된다
- 잠금화면에서 바로 할일을 완료하고 활동을 닫을 수 있다 (`CompleteTodoAndEndLiveActivityIntent`), 닫기만 하는 `EndLiveActivityIntent`도 있다
- 활동을 탭하면 해당 이벤트 상세로 딥링크한다

---

## 상세 스펙 파일 목록

| 파일 | 내용 |
|---|---|
| [spec/screens.md](spec/screens.md) | 화면 구성 — 캘린더 그리드, 이벤트 상세, 완료 목록, 설정, 인증 |
| [spec/todo-event.md](spec/todo-event.md) | 할일 — CRUD, 완료/되돌리기, 건너뛰기, 조회 |
| [spec/schedule-event.md](spec/schedule-event.md) | 일정 — 수정 범위, 캐시, 제외 목록 |
| [spec/repeating-events.md](spec/repeating-events.md) | 반복 — 6가지 옵션, 계산 알고리즘, turn 규칙 |
| [spec/uncompleted-todos.md](spec/uncompleted-todos.md) | 미완료 할일 — 판정 기준, 갱신 트리거 |
| [spec/account-auth.md](spec/account-auth.md) | 계정 — OAuth2, Factory 전환, DB 분리, 마이그레이션 |
| [spec/sync.md](spec/sync.md) | 동기화 — 오프라인 큐, API, 충돌 해결, 백그라운드 |
| [spec/settings.md](spec/settings.md) | 설정 — UserDefaults 키, 기본값, 화면 매트릭스 |
| [spec/infrastructure.md](spec/infrastructure.md) | 인프라 — SharedDataStore, 딥링크, 피드백, D-Day, DB 마이그레이션 |
| [spec/tags-foremost-notifications.md](spec/tags-foremost-notifications.md) | 태그 + 강조 이벤트 + 알림 — CRUD, 색상 체계, 상태 전이, fire date, 라이프사이클 |
| [spec/google-calendar.md](spec/google-calendar.md) | 구글 캘린더 — OAuth, 다중 계정 Pool, 연동/해제 플로우, DB 스키마 |
| [spec/widgets.md](spec/widgets.md) | 위젯 (19종 + Control) — 사이즈 매트릭스, Intent, Timeline, App Group, 딥링크 |
| [spec/apple-calendar.md](spec/apple-calendar.md) | Apple 캘린더 — 권한 분기, EventKit 캐시, RRULE 변환, 쓰기 범위 |
| [spec/ai-agent.md](spec/ai-agent.md) | AI 에이전트 — Command/Job/Mutation, 상태 머신, 폴링·푸시, 확인 플로우, 사용량 |
| [spec/billing.md](spec/billing.md) | 과금 — 플랜·top-up, 구매·복원 순서, paywall, 광고 노출 판정 |
