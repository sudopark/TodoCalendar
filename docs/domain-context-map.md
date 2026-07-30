# 도메인 컨텍스트 지도 (DDD)

> 이 프로젝트로 대화·작업할 때 깔고 가는 **공통 언어**. 경계와 용어를 여기에 맞춘다.
> 영역별 상세는 각 행의 링크(`docs/spec/*`) 참조 — 여기선 중복하지 않는다.

## 도메인 한 줄 정의

**"할 일·일정을 시간 위에 배치하고, 반복·완료를 추적한다."** 이게 존재 이유(Core)다.

## Bounded Context 지도

단일 도메인 + 9개 서브도메인. 폴더 구조(`Domain/Sources/{Models,Usecases,Repositories}/*`)가 곧 context 경계.

| # | Bounded Context | 분류 | 핵심 책임 | 상세 |
|---|---|---|---|---|
| 1 | **Event** | 🟥 Core | Todo/Schedule 생성·수정·반복·완료·태깅·강조 | [todo](spec/todo-event.md) · [schedule](spec/schedule-event.md) · [repeating](spec/repeating-events.md) · [tags/foremost](spec/tags-foremost-notifications.md) |
| 2 | **Calendar** | 🟥 Core | 시간 프레임(연/월/일·주·음력)·포커스 날짜·공휴일 | `Models/Calendar`, `CalendarUsecase`, `HolidayUsecase` |
| 3 | **External Calendar** | 🟧 Supporting | Google/Apple 외부 캘린더 다중계정 연동·합산 | [google-calendar](spec/google-calendar.md) |
| 4 | **Account / Auth** | 🟧 Supporting | 로그인·토큰·OAuth2·외부 서비스 계정 | [account-auth](spec/account-auth.md) |
| 5 | **AI Agent** | 🟧→🟥 Supporting (Core 승격 유력) | 음성/키보드 command → 이벤트 변경 오케스트레이션 | `Models/AI`, `AIAgentOrchestrationUsecase` |
| 6 | **Notification** | 🟧 Supporting | 이벤트 알림 스케줄링·권한 | [tags/foremost/notifications](spec/tags-foremost-notifications.md) |
| 7 | **Settings** | 🟩 Generic | 외형·이벤트 표시·UI 설정 | [settings](spec/settings.md) |
| 8 | **Support** | 🟩 Generic | 앱 업데이트·피드백·링크프리뷰·장소검색·STT | [infrastructure](spec/infrastructure.md) |
| 9 | **Billing** | 🟧 Supporting | 플랜·top-up 카탈로그, StoreKit 구매 → 서명 서버 반영 | `Models/Billing`, `BillingUsecase`, `StoreKitService` |

**분류 의미** — 🟥 Core: 제품 차별점, 투자 집중 / 🟧 Supporting: Core를 떠받침 / 🟩 Generic: 어디서든 동일, 대체 가능.

## Ubiquitous Language — 오해 나는 지점

전체 용어집이 아니라 **다르게 쓰기 쉬운 것만**. 나머지 용어는 CLAUDE.md §4와 각 spec에 있다.

| 용어 | 코드상 정확한 의미 | 자주 나는 오해 |
|---|---|---|
| **Event(이벤트)** | Todo + Schedule (+ External)의 **상위 개념** | "이벤트 = Schedule"로 좁힘 |
| **Todo** | 시간 **선택적**, 완료 시 `DoneTodo` 생성, count 기반 반복 종료 | Schedule과 완료 방식 동일하다 착각 |
| **Schedule** | 시간 **필수**, 완료 개념 없음(삭제만), `RepeatingTimes` 사전계산 | "완료된 일정" (존재 안 함) |
| **turn / 회차** (`repeatingTurn`) | 반복의 **1-based 회차 인덱스**. `nil`=turn 1 | 0-based로 세기 |
| **series vs occurrence** | Schedule 수정범위: `.onlyThisTime`(이 회차만) / `.fromNow`(여기부터 분기) / 전체 시리즈 | "이 일정 수정"이 시리즈 전체인지 한 회차인지 모호 |
| **Foremost** | 사용자가 **딱 1개** 지정하는 강조 이벤트(위젯용) | 복수로 오해 |
| **Tag** | `EventTagId` 4종: `.default`/`.holiday`/`.custom`/`.externalCalendar`. 표시 semantics 다름(커스텀 기본보임, 외부 기본숨김) | 단순 라벨로만 |
| **Command vs Job** (AI) | `ProcessingAICommand`=클라 의도 / `AIJob`=서버 실행단위(PENDING·RUNNING·DONE·CONFIRM·FAILED·REJECTED) / `AIJobDataMutation`=결과 반영(todo/doneTodo/schedule/tag/eventDetail × created/updated/deleted) | 셋을 뭉뚱그려 "AI 요청" |
| **External Calendar** | Google/Apple **한정**, accountId별 Pool로 다중계정, `LocalAggregated`가 합산 | "외부 = Google만" |
| **Done** | Todo 전용 완료 상태(`DoneTodoEvent`) | Schedule에도 있다고 가정 |

## Context 간 관계 (핵심 흐름만)

- **AI Agent → Event**: command가 `AIJobDataMutation`으로 Event를 변경. AI는 Event의 소비자.
- **External Calendar → Event/Tag**: 외부 이벤트는 `externalCalendar` 태그로 Event 뷰에 합산. Account가 연동 자격 공급.
- **Calendar → Event**: Calendar가 시간 프레임/포커스를 제공, 그 위에 Event가 배치됨.
- **Notification → Event**: Event 시간 기준으로 알림 스케줄.
- **AI Agent → Billing**: AI 사용 한도가 Billing 플랜에서 나온다. 단방향 — Billing 은 AI 를 모른다. 서버가 같은 방향으로 갈랐고, 위젯 Pro 도 같은 인프라를 쓸 예정이라 Billing 은 AI 하위가 아닌 독립 context 다.
