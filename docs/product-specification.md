# TodoCalendar 제품 기획서

> 코드베이스 기반 기능/정책 명세. 최종 갱신: 2026-04-01 (Phase 3~5 상세 추가)
>
> 각 섹션의 상세 스펙은 `spec/` 하위 파일을 참조.

---

## 1. 앱 개요

| 항목 | 내용 |
|---|---|
| 플랫폼 | iOS 17+ |
| 아키텍처 | 오프라인 우선 (Offline-First), MVVM + Router + Builder |
| UI | SwiftUI + UIKit 하이브리드 |
| 빌드 | Tuist v3, Swift 6.0 |
| App Scheme | `tc.app://` |
| App Store ID | `6639620385` |
| App Group | `group.sudo.park.todo-calendar` |

**핵심 가치**: 캘린더와 할일을 하나의 앱에서 통합 관리. 로그인 없이도 모든 핵심 기능 사용 가능하며, 로그인 시 클라우드 동기화 제공.

---

## 2. 화면 구성

> **상세 스펙**: [spec/screens.md](spec/screens.md) — 캘린더 그리드 정렬 알고리즘, 모드별 필드 매트릭스, 저장 조건, 필드 연동, 에러 표시 패턴

### 2.1 메인 캘린더
- 월별 캘린더 그리드 (좌우 스와이프 무한 페이징, 3개월 윈도우)
- 이벤트 색상 바 표시 + "+N 더보기" 인디케이터
- 일별 이벤트 목록 (강조 이벤트, 미완료 할일, 이벤트, 빠른 입력)
- 이벤트 정렬: 시간 없는 할일 → 시간 있는 할일 → 일정 → 공휴일 → 구글 이벤트

### 2.2 이벤트 상세
- 6가지 모드: 생성(Add), 할일 수정, 일정 수정, 공휴일, 구글 캘린더, 완료 할일
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
├── 외형 설정 (캘린더 외형, 컬러 테마, 타임존, 위젯 외형)
├── 이벤트 설정 (기본 태그, 기본 알림, 기본 지도 앱)
├── 공휴일 설정 (국가 선택)
├── 피드백 전송
└── 도움말 / 앱 공유 / 리뷰 / 소스코드
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

- **읽기 전용**, 다중 계정 동시 지원, Google OAuth2
- 연동: OAuth → 자격증명 저장(Keychain) → DB 연결(참조 카운팅) → 색상/캘린더/이벤트 동기화
- 해제: 자격증명 삭제 → DB 해제 → SharedDataStore 정리 → 태그 off 정리
- 캘린더별 보이기/숨기기 (기본 숨김, 사용자 활성화)
- 이벤트 상세: 참석자, 회의 링크, 첨부파일, 상태(확정/미정/취소) — "구글에서 편집" 링크
- 토큰 자동 갱신 (Alamofire AuthenticationInterceptor), 갱신 실패 시 재인증

---

## 9. 위젯 (18종)

> **상세 스펙**: [spec/widgets.md](spec/widgets.md) — 위젯별 사이즈 매트릭스, Timeline 갱신 정책, Intent 파라미터, 데이터 소스, App Group 공유, 딥링크 URL, 캐시 메커니즘

| 분류 | 위젯 |
|---|---|
| 기본 (7) | TodayAndNext, Today, NextEvent, NextRemainEvent, ForemostEvent, Month, EventList |
| 주/월 (7) | 1~4주, 이번달/지난달/다음달 |
| 조합 (4) | TodayAndMonth, EventAndMonth, EventAndForemost, DoubleMonth |

- `TodoToggleIntent`: 위젯에서 할일 완료 토글 (SQLite 직접 쓰기 + 캐시 리셋)
- `EventTypeSelectIntent`: 태그 기반 위젯 필터링 (커스텀+구글 태그 지원)
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
- 메인 DB v6, 외부 캘린더 DB v0
- 버전별 `migrateStatement` + `AppEnvironment.dbVersion` 동시 변경 필수

### 외부 의존성
- Alamofire, Kingfisher, SQLiteService, Firebase(Messaging), AppAuth, Combine 등
- Tuist v3 + SPM, dynamic framework

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
| [spec/widgets.md](spec/widgets.md) | 위젯 (18종) — 사이즈 매트릭스, Intent, Timeline, App Group, 딥링크 |
