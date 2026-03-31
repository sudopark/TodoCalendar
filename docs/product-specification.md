# TodoCalendar 제품 기획서

> 코드베이스 기반 기능/정책 명세. 최종 갱신: 2026-03-31

---

## 1. 앱 개요

| 항목 | 내용 |
|---|---|
| 플랫폼 | iOS 17+ |
| 아키텍처 | 오프라인 우선 (Offline-First), MVVM + Router + Builder |
| UI | SwiftUI + UIKit 하이브리드 |
| 빌드 | Tuist v3, Swift 6.0 |
| App Scheme | `tc.app://` |

**핵심 가치**: 캘린더와 할일을 하나의 앱에서 통합 관리. 로그인 없이도 모든 핵심 기능 사용 가능하며, 로그인 시 클라우드 동기화 제공.

---

## 2. 화면 구성

### 2.1 메인 캘린더 (`CalendarScene`)

월별 캘린더 그리드 + 선택일 이벤트 목록으로 구성된 메인 화면.

#### 2.1.1 캘린더 그리드

좌우 스와이프로 월 이동하는 캘린더 그리드. UIPageViewController 기반 무한 페이징.

**무한 페이징 구조**

항상 3개월 윈도우 `[이전월, 현재월, 다음월]`을 유지한다. 포커스 인덱스는 1(가운데).

| 동작 | 결과 |
|---|---|
| 오른쪽 스와이프 (다음 월) | 배열에서 가장 이전 월을 제거하고, 끝에 새 다음월 추가 |
| 왼쪽 스와이프 (이전 월) | 배열에서 가장 최신 월을 제거하고, 앞에 새 이전월 추가 |

월 변경 시 아직 로드하지 않은 범위의 이벤트·공휴일만 추가로 요청한다 (`TotalMonthRanges`로 이미 체크한 범위 추적).

**이벤트 색상 바 표시 규칙**

캘린더 셀에 해당 날짜의 이벤트를 색상 바(rounded rectangle, cornerRadius: 2)로 표시한다.

- 단일 날짜 이벤트: 해당 날짜 셀에 1줄 바
- 기간(period) 이벤트: 여러 날에 걸쳐 배경 바(50% opacity) + 3pt 좌측 색상 바
- 색상 출처: 이벤트의 태그 색상 (구글 캘린더 이벤트는 별도 `GoogleCalendarEventColorSource` 참조)

**이벤트 스택 정렬 알고리즘** (`WeekEventStackBuilder`)

주 단위로 이벤트를 행(row)에 배치한다. 정렬 기준 (우선순위 순):

1. **이벤트 길이** — 기간이 긴 이벤트가 위 행에 배치
2. **시작 요일** — 더 이른 날짜의 이벤트가 우선
3. **기존 행 수** — 이미 적은 행을 사용 중인 이벤트가 우선

배치 방식: 전체 주(1...7)를 차지하는 이벤트를 먼저 별도 행에 배치한 뒤, 나머지를 재귀적으로 빈 공간에 채운다. 같은 행에서 겹치지 않는 이벤트끼리 좌/우 이웃으로 배치.

**"+N" 더보기 인디케이터**

셀 높이에 따라 표시 가능한 최대 행 수가 결정된다:

```
maxDrawableEventRowCount = (셀높이 - eventTopMargin) / eventRowHeightWithSpacing - 1
```

- 표시 가능 행 수 < 전체 행 수: 숨겨진 행의 이벤트 수를 날짜별로 집계하여 "+N" 텍스트로 표시
- 표시 가능 행 수 ≥ 전체 행 수: 모든 이벤트 표시, 하단 여백 처리

**날짜 선택 규칙**

| 상태 | 선택 날짜 |
|---|---|
| 사용자가 날짜 탭 | 탭한 날짜 |
| 사용자 선택 없이 오늘이 속한 월을 볼 때 | 오늘 |
| 사용자 선택 없이 다른 월을 볼 때 | 해당 월의 1일 |

**기타 인터랙션**

- 공휴일/주말 강조 표시 (색상 구분)
- 오늘 날짜 하이라이트
- "오늘" 버튼: 오늘이 속한 3개월 윈도우로 재구성 → 오늘 날짜 선택 초기화
- 날짜 롱프레스 → `SelectDayDialog` (SwiftUI DatePicker `.graphical` 스타일 바텀시트)
  - 날짜 선택 후 확인 → `SelectDayInfo` 전달 (같은 해/같은 날 플래그 포함)

#### 2.1.2 일별 이벤트 목록 (`DayEventList`)

선택 날짜의 이벤트를 표시하는 목록. 다음 순서로 섹션이 구성된다:

| 순서 | 섹션 | 조건 |
|---|---|---|
| 1 | 강조 이벤트 (Foremost Event) | 사용자가 지정한 경우에만 |
| 2 | 미완료 할일 목록 | 설정에서 활성화한 경우에만 |
| 3 | 날짜 정보 (양력 + 음력 + 공휴일명) | 항상 |
| 4 | 이벤트 목록 | 항상 |
| 5 | 빠른 할일 입력 (QuickAddNewTodo) | 항상 |
| 6 | 새 이벤트 추가 버튼 (+일정 / +할일) | 항상 |

**이벤트 정렬 규칙**

이벤트 목록 섹션 내에서의 정렬 순서:

1. **시간 없는 할일 (current todos)** — `createdAt` 오름차순. 둘 다 `nil`이면 이름 알파벳순
2. **시간 있는 할일** — `EventTime` 기준 오름차순
3. **일정** — `EventTime` 기준 오름차순
4. **공휴일** — 원래 순서 유지
5. **구글 캘린더 이벤트** — 원래 순서 유지

**이벤트 셀 구성**: 타입 아이콘, 이름(1줄), 시간 텍스트, 태그 색상 바

#### 2.1.3 화면 간 네비게이션

| 출발 | 도착 | 트리거 |
|---|---|---|
| 이벤트 목록 셀 탭 | 이벤트 상세 (모드에 따라 분기) | 셀 탭 |
| "+할일" 버튼 | 이벤트 상세 (Add, 할일 모드) | 버튼 탭 |
| "+일정" 버튼 | 이벤트 상세 (Add, 일정 모드) | 버튼 탭 |
| "완료 목록" 버튼 | 완료 할일 목록 | 버튼 탭 |
| 빠른 입력 → 상세 | 이벤트 상세 (Add, 할일 모드, 이름 프리필) | 상세 추가 버튼 |

---

### 2.2 이벤트 상세 (`EventDetailScene`)

하나의 화면에서 생성/수정/조회를 모두 처리. ViewModel 변형으로 모드 분기.

#### 2.2.1 모드

| 모드 | ViewModel | 설명 |
|---|---|---|
| 생성 (Add) | `AddEventViewModelImple` | 할일/일정 타입 선택 후 새 이벤트 생성 |
| 할일 수정 (EditTodo) | `EditTodoEventDetailViewModelImple` | 기존 할일 편집 |
| 일정 수정 (EditSchedule) | `EditScheduleEventDetailViewModelImple` | 기존 일정 편집 |
| 공휴일 상세 (Holiday) | `HolidayEventDetailViewModelImple` | 읽기 전용, D-Day 카운트다운 |
| 구글 캘린더 상세 (GoogleCalendar) | `GoogleCalendarEventDetailViewModelImple` | 읽기 전용, 구글에서 편집 링크 제공 |
| 완료 할일 상세 (DoneTodo) | `DoneTodoDetailViewModelImple` | 읽기 전용, 완료 취소(되돌리기) 가능 |

#### 2.2.2 모드별 필드 매트릭스

| 필드 | Add | EditTodo | EditSchedule | Holiday | GoogleCal | DoneTodo |
|---|---|---|---|---|---|---|
| 이름 | 편집 | 편집 | 편집 | 표시 | 표시 | 표시 |
| 타입 토글 (할일/일정) | **활성** | 비활성 | 비활성 | — | — | — |
| 날짜/시간 | 편집 | 편집 | 편집 | 표시 | 표시 | 표시 (원본+완료시간) |
| 하루종일 토글 | 편집 | 편집 | 편집 | — | — | — |
| 기간 (종료시간) | 편집 | 편집 | 편집 | — | 표시 | — |
| 반복 | 편집 | 편집 | 편집 | — | 표시 (RRULE 파싱) | — |
| 알림 (복수) | 편집 | 편집 | 편집 | — | — | 표시 |
| 태그/색상 | 편집 | 편집 | 편집 | — | 표시 (캘린더명) | 표시 |
| 위치 | 편집 | 편집 | 편집 | — | 표시 | 표시 |
| URL | 편집 | 편집 | 편집 | — | — | 표시 |
| 메모 | 편집 | 편집 | 편집 | — | 표시 (description) | 표시 |
| D-Day | — | — | — | 표시 | 표시 | — |
| 컨퍼런스 링크 | — | — | — | — | 표시 | — |
| 참석자 | — | — | — | — | 표시 | — |
| 첨부파일 | — | — | — | — | 표시 | — |
| 강조 이벤트 (Foremost) | 비활성 | 표시+토글 | 표시+토글 | — | — | — |
| 추가 액션 (더보기) | — | 활성 | 활성 | — | 편집 링크 | 되돌리기 |

#### 2.2.3 저장 버튼 활성화 조건

저장 버튼은 `isSavable` 상태에 따라 활성/비활성 처리된다.

**할일 (Add 할일 모드 / EditTodo)**

```
isSavable = 이름이 비어있지 않음 AND 선택된 시간이 유효하지 않은 상태가 아님
```

- 시간 미선택(`nil`)은 허용 — 시간 없는 할일
- 시간 선택 후 기간의 시작 ≥ 종료인 경우만 invalid

**일정 (Add 일정 모드 / EditSchedule)**

```
isSavable = 이름이 비어있지 않음 AND 선택된 시간이 명시적으로 유효함
```

- 시간 필수 — `nil`이면 저장 불가
- 기간 이벤트: 시작 < 종료 필수

**시간 유효성 판정 (`SelectedTime.isValid`)**

| 시간 타입 | 유효 조건 |
|---|---|
| `.at(date)` | 항상 유효 |
| `.singleAllDay(date)` | 항상 유효 |
| `.period(start, end)` | `start.date < end.date` |
| `.alldayPeriod(start, end)` | `start.date < end.date` |

#### 2.2.4 필드 간 연동 규칙

**하루종일 토글 변경 시**

| 변경 | 영향 |
|---|---|
| 일반 → 하루종일 | `.at()` → `.singleAllDay()` / `.period()` → `.alldayPeriod()` (타임존 오프셋 적용) |
| 하루종일 → 일반 | `.singleAllDay()` → `.at()` / `.alldayPeriod()` → `.period()` |
| 양방향 공통 | **알림 옵션 전체 초기화** (하루종일과 일반의 알림 옵션 체계가 다르므로) |

**시간 ↔ 반복**

- 반복 옵션 선택 시 유효한 시간이 반드시 필요. 시간 미선택 상태에서 반복 선택 시도 → 토스트: `"eventDetail.Messages.selectTimeFirst"`
- 시작 시간 변경 시 반복의 기준 시작 시간도 자동 업데이트

**시간 ↔ 알림**

- 알림 시간 선택 시 유효한 시간이 반드시 필요. 시간 미선택 상태에서 알림 선택 시도 → 토스트: `"eventDetail.Messages.selectTimeFirst"`
- 커스텀 알림: 이벤트 시간의 `DateComponents`를 기준으로 상대 시간 계산

**종료 시간 제약**

- 종료 시간 ≤ 시작 시간으로 설정 시 변경이 무시됨 (유효하지 않은 기간 방지)

#### 2.2.5 저장/수정 플로우

**새 이벤트 생성 (Add)**

```
1. save() 호출
2. isTodo 플래그에 따라 분기
   ├─ 할일: TodoMakeParams 빌드 → todoUsecase.makeTodoEvent()
   └─ 일정: ScheduleMakeParams 빌드 → scheduleUsecase.makeScheduleEvent()
3. isSaving = true (저장 중 인디케이터)
4. 성공 시:
   ├─ 부가 데이터 저장 (메모, URL, 위치)
   ├─ 토스트 표시
   └─ 화면 닫기
5. 실패 시:
   ├─ 에러 다이얼로그 표시
   └─ isSaving = false
```

**기존 이벤트 수정 (EditTodo / EditSchedule)**

```
1. save() 호출
2. 변경 사항 확인 (basic.isChanged OR addition.isChanged)
   └─ 변경 없음 → 바로 화면 닫기
3. 원본이 반복 이벤트인 경우 → 수정 범위 선택 ActionSheet 표시
4. 수정 범위에 따라 파라미터 빌드 → usecase.update...()
5. 성공/실패 처리 (생성과 동일)
```

**반복 이벤트 수정 범위 선택**

| 수정 대상 | 할일 (EditTodo) | 일정 (EditSchedule) |
|---|---|---|
| 반복 시작 시점을 편집 | "지금부터" / "이번만" | "전체" / "이번만" |
| 다른 회차를 편집 | "지금부터" / "이번만" | "지금부터(targetTime)" / "이번만(targetTime)" |

- "전체": 시리즈 전체에 적용
- "지금부터": 현재 시점부터 미래 반복을 새 시리즈로 분기
- "이번만": 해당 회차만 수정 (반복 설정 제거, 원본에서 해당 시간 제외)

#### 2.2.6 추가 액션 (수정 모드)

| 액션 | EditTodo | EditSchedule | 조건 |
|---|---|---|---|
| 삭제 | O | O | 반복 이벤트: 이번만/전체 범위 선택 |
| 복사 | O | O | — |
| 타입 변환 (할일→일정) | O | — | 이름 + 시간 필수 (없으면 토스트) |
| 타입 변환 (일정→할일) | — | O | 이름 필수. 반복 이벤트의 시작 시점이 아닌 경우 비활성 |
| 강조 이벤트 토글 | O | O | — |

**타입 변환 플로우**

```
1. 유효성 검증 (이름 + 시간)
   └─ 실패 시 토스트: "eventDetail.unavailto_transform_withoutName" 또는
                      "eventDetail.todoEvent_unavailto_transform_withoutTime"
2. 확인 다이얼로그 표시
3. 새 타입으로 이벤트 생성 → 기존 이벤트 삭제
4. Listener 콜백으로 부모에게 전환 결과 전달
```

#### 2.2.7 하위 모달

**반복 옵션 선택 (`SelectEventRepeatOption`)**

진입 조건: 유효한 시간이 선택되어 있어야 함.

제공 옵션 (2개 섹션):

| 섹션 1 (기본) | 설명 |
|---|---|
| 매일 | — |
| 매주 (현재 요일) | — |
| 매 2/3/4주 (현재 요일) | — |
| 매월 (같은 일자) | — |
| 매년 (같은 날짜) | — |
| 음력 매년 | — |

| 섹션 2 (조건부) | 조건 |
|---|---|
| 매 평일 | 시작일이 주말이 아닌 경우만 |
| 매월 (모든 요일) | — |
| 매월 (N번째 특정 요일) | 예: "매월 첫 번째 화요일" |

종료 옵션:

| 옵션 | 설명 |
|---|---|
| 반복 종료 없음 | 무한 반복 |
| 특정 날짜까지 | DatePicker로 선택. 시작 < 종료 필수 (위반 시 토스트) |
| N회 반복 후 | 정수 입력 |

**태그 선택 (`SelectEventTag`)**

- `.holiday` 태그는 목록에서 제외
- 기본 태그가 목록 상단에 정렬
- 태그 생성/관리 화면으로 이동 가능 (SettingScene 연동)
- 태그 생성/수정/삭제 이벤트가 실시간으로 목록에 반영

**알림 시간 선택 (`SelectEventNotificationTime`)**

진입 조건: 유효한 시간이 선택되어 있어야 함.

- `isForAllDay` 플래그에 따라 제공되는 기본 옵션이 다름
- 기본 옵션 토글(선택/해제) + 커스텀 시간 추가/삭제
- 시스템 알림 권한 확인: `.notDetermined` → 권한 요청, `.denied` → 안내 표시
- 선택 변경 시 실시간으로 메인 폼에 반영 (Listener 콜백)

**지도 앱 선택 (`SelectMapApp`)**

| 앱 | ID |
|---|---|
| Apple Maps | `.apple` |
| Google Maps | `.google` |
| Naver Maps | `.naver` |
| Kakao Maps | `.kakao` |

- 기본 지도 앱 설정이 있으면 선택 없이 바로 열기
- 기본 앱이 없으면 설치된 앱 목록에서 선택

---

### 2.3 완료 할일 목록 (`DoneTodoEventListScene`)

완료 처리된 할일을 시간순으로 조회하는 목록 화면.

#### 2.3.1 그룹핑 규칙

완료 날짜(`doneTime`)를 기준으로 2단계 그룹핑을 적용한다.

**섹션 타이틀** (세밀한 단위):

| 조건 | 타이틀 |
|---|---|
| 오늘 완료 | "오늘" |
| 어제 완료 | "어제" |
| 그 외 | `yyyy_MM_dd` 형식 |

**섹션 그룹 타이틀** (굵은 단위, 그룹 변경 시에만 표시):

| 조건 | 그룹 타이틀 |
|---|---|
| 오늘 | "오늘" |
| 어제 | "어제" |
| 올해 같은 달 | "이번 달" |
| 올해 다른 달 | 월 번호 (MM) |
| 다른 해 | 연도 (yyyy) |

그룹 타이틀은 직전 섹션과 그룹이 달라질 때만 `shouldShowSectionGroupTitle = true`로 표시.

#### 2.3.2 페이지네이션

- **커서 기반**: 마지막 아이템의 `doneTime.timeIntervalSince1970`을 다음 페이지 커서로 사용
- **초기 로드**: `cursorAfter: nil`
- **추가 로드**: 목록 하단 도달 시 자동 트리거 (무한 스크롤)
- **중복 제거**: 여러 페이지의 결과를 `uuid` 기준으로 병합

#### 2.3.3 완료 취소 (되돌리기)

두 가지 경로로 되돌리기 가능:

**목록에서 직접 되돌리기**

1. 완료 아이콘(체크 표시) 탭 → 아이콘이 빈 원으로 변경 (시각적 피드백)
2. 비동기 Task로 `todoUsecase.revertCompleteTodo()` 호출
3. 성공 시 해당 아이템을 목록에서 제거 (`revertedIdSet`으로 필터링)
4. 실패 시 에러 다이얼로그 표시

**상세 화면에서 되돌리기**

1. 셀 탭 → 완료 할일 상세 (DoneTodo 모드) 화면 이동
2. "되돌리기" 버튼 탭 → `listener.doneTodoDetail(revert:to:)` 콜백
3. 목록 화면이 Listener로서 콜백 수신 → `revertedIdSet` 업데이트 → 섹션 재계산

#### 2.3.4 일괄 삭제

ActionSheet로 삭제 범위를 선택한다:

| 옵션 | 동작 |
|---|---|
| 전체 삭제 | 모든 완료 할일 삭제 |
| 1개월 이전 | 1개월보다 오래된 완료 할일 삭제 |
| 3개월 이전 | 3개월보다 오래된 완료 할일 삭제 |
| 6개월 이전 | 6개월보다 오래된 완료 할일 삭제 |
| 1년 이전 | 1년보다 오래된 완료 할일 삭제 |

삭제 중 `isRemovingTodos = true`로 프로그레스 인디케이터를 표시하고, 완료 후 목록을 다시 로드한다.

---

### 2.4 설정 (`SettingItemListViewController`)

**메뉴 구조**
```
설정
├── 계정 (로그인/계정 관리)
├── 외형 설정
│   ├── 캘린더 외형
│   ├── 컬러 테마
│   ├── 타임존
│   └── 위젯 외형
├── 이벤트 설정
│   ├── 기본 태그
│   ├── 기본 알림 시간
│   └── 기본 지도 앱
├── 공휴일 설정
│   └── 국가 선택
├── 피드백 전송
├── 도움말 (외부 링크)
├── 앱 공유
├── 앱스토어 리뷰
└── 소스코드 (GitHub)
```

### 2.5 인증 (`MemberScenes`)

| 화면 | 설명 |
|---|---|
| 로그인 | 바텀시트 모달, 구글 OAuth2 |
| 계정 관리 | 로그인 방법, 이메일, 최종 로그인 시간 표시. 로그아웃/계정 삭제/데이터 마이그레이션 |

### 2.6 에러 표시 패턴

모든 화면에서 공통으로 사용하는 에러 표시 메커니즘:

**에러 다이얼로그** (`showError`)

- `RuntimeError` / `ServerErrorModel` → 에러 메시지 추출
- 기본 에러 메시지 + 상세 메시지를 함께 표시
- 확인 버튼만 있는 단일 액션 다이얼로그
- `ServerErrorModel.code == .cancelled`인 경우 무시 (사용자 취소)

**토스트** (`showToast`)

- 짧은 알림 메시지용 (저장 완료, 유효성 안내 등)
- 자동 사라짐

**확인 다이얼로그** (`showConfirm`)

- 제목, 메시지, 확인/취소 버튼
- 삭제, 타입 변환 등 되돌리기 어려운 액션의 사전 확인용

**ActionSheet** (`showActionSheet`)

- 반복 이벤트 수정/삭제 범위 선택, 일괄 삭제 범위 선택 등 다중 선택지 제공

### 2.7 화면 간 데이터 전달 패턴

모든 화면 간 데이터 전달은 3가지 메커니즘을 사용한다:

| 방향 | 메커니즘 | 용도 |
|---|---|---|
| 간접 공유 | `SharedDataStore` (Usecase 경유) | 같은 데이터를 구독하는 독립 화면 간 (캘린더 ↔ 이벤트 목록 등) |
| 부모 → 자식 | `Interactor` 프로토콜 | 부모가 자식에게 명령 전달 |
| 자식 → 부모 | `Listener` 프로토콜 (weak 참조) | 자식이 부모에게 이벤트 전달 |

**Builder/Router 조립 패턴**:

```
Builder.make...Scene(listener) → ViewController 생성
  ├─ ViewModel 생성 (usecase 주입)
  ├─ Router 생성 (하위 Builder 주입)
  ├─ Router.scene = ViewController
  ├─ ViewModel.router = Router
  └─ ViewController.interactor = ViewModel
```

Router가 하위 화면을 생성할 때 `currentScene?.interactor`를 Listener로 전달하여, 자식 화면의 결과가 부모 ViewModel에 직접 콜백된다.

---

## 3. 이벤트 모델

### 3.1 할일 (TodoEvent)

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 고유 식별자 |
| name | String | 이벤트 이름 (필수) |
| eventTagId | EventTagId? | 태그/색상 |
| time | EventTime? | 시간 (없으면 단순 할일) |
| repeating | EventRepeating? | 반복 설정 |
| repeatingTurn | Int? | 현재 반복 회차 (nil = turn 1) |
| notificationOptions | [EventNotificationTimeOption] | 알림 시간 목록 |

**생명주기**
```
[미완료] ──완료──→ [DoneTodoEvent 생성]
                       │
                   완료 취소
                       │
                       ↓
                  [TodoEvent 복원]
```

**완료 처리 규칙**
| 조건 | 동작 |
|---|---|
| 시간 없음 | 할일 삭제 → DoneTodoEvent 생성 |
| 시간 있음, 반복 없음 | 할일 삭제 → DoneTodoEvent 생성 |
| 시간 있음, 반복 있음 | 할일 유지 (다음 반복) → DoneTodoEvent 생성 |

### 3.2 일정 (ScheduleEvent)

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 고유 식별자 |
| name | String | 이벤트 이름 (필수) |
| time | EventTime | 시간 (필수) |
| eventTagId | EventTagId? | 태그/색상 |
| repeating | EventRepeating? | 반복 설정 |
| showTurn | Int | 표시 회차 |
| notificationOptions | [EventNotificationTimeOption] | 알림 시간 목록 |
| nextRepeatingTimes | [RepeatingTimes] | 사전 계산된 다음 반복 시간들 |
| repeatingTimeToExcludes | Set\<String\> | 제외된 반복 시간 |

### 3.3 EventTime (시간 표현)

| 형태 | 설명 | 예시 |
|---|---|---|
| `.at(TimeInterval)` | 특정 시점 | 할일 마감 시각 |
| `.period(Range<TimeInterval>)` | 기간 | 회의 시작~종료 |
| `.allDay(Range<TimeInterval>, secondsFromGMT)` | 하루종일 | 타임존 오프셋 별도 저장 |

### 3.4 DoneTodoEvent (완료 할일)

| 속성 | 타입 | 설명 |
|---|---|---|
| uuid | String | 고유 식별자 |
| originEventId | String | 원본 할일 ID |
| name | String | 이벤트 이름 |
| doneTime | TimeInterval | 완료 시각 |
| eventTime | EventTime? | 원본 예정 시간 |

### 3.5 이벤트 상세 데이터 (EventDetailData)

모든 이벤트 타입에 공통으로 첨부 가능한 부가 정보.

| 속성 | 타입 | 설명 |
|---|---|---|
| place | Place? | 장소명 + 좌표 + 주소 |
| url | String? | 링크 |
| memo | String? | 메모 |

---

## 4. 반복 이벤트

### 4.1 반복 옵션 (6가지)

| 옵션 | 파라미터 | 예시 |
|---|---|---|
| 매일 (EveryDay) | interval: 1~999일 | 3일마다 |
| 매주 (EveryWeek) | interval: 1~5주, 요일 선택, 타임존 | 매주 월·수·금 |
| 매월 (EveryMonth) | interval: 1~11개월, 일자 또는 N번째 요일, 타임존 | 매월 15일 / 매월 첫째 화요일 |
| 매년 (EveryYear) | interval: 1~99년, 월 선택, 요일 서수, 타임존 | 매년 3월 |
| 매년 특정일 (EveryYearSomeDay) | month, day, 타임존 | 매년 12월 25일 |
| 음력 매년 (LunarCalendarEveryYear) | month, day, 타임존 | 음력 1월 1일 |

### 4.2 종료 조건

| 조건 | 설명 |
|---|---|
| 없음 | 무한 반복 |
| `.until(TimeInterval)` | 특정 날짜까지 |
| `.count(Int)` | 총 N회 (예: count=3이면 turn 1·2·3 유효, turn 4부터 종료) |

### 4.3 반복 수정 범위

**일정 (ScheduleEvent)**
| 범위 | 동작 |
|---|---|
| `.all` | 원본 이벤트 전체 수정 |
| `.onlyThisTime(EventTime)` | 해당 회차를 원본에서 제외(exclude), 새 단독 이벤트 생성 |
| `.fromNow(EventTime)` | 원본의 반복을 현재 시점에서 종료, 새 반복 시리즈 생성 |

**할일 (TodoEvent)**
| 범위 | 동작 |
|---|---|
| `.all` | 원본 전체 수정 |
| `.onlyThisTime` | 현재 회차용 새 이벤트 생성 + 원본 건너뛰기 |

### 4.4 건너뛰기 (할일 전용)

| 옵션 | 동작 |
|---|---|
| `.next` | 다음 1회 건너뛰기 (repeatingTurn 증가) |
| `.until(EventTime)` | 지정 시간까지 건너뛰기 (시간 변경) |

### 4.5 Turn 규칙

- turn은 **1부터 시작**
- `TodoEvent.repeatingTurn`: 현재 반복 회차. `nil` = turn 1로 취급
- 완료/수정/삭제/스킵마다 다음 turn으로 업데이트
- count 기반 종료 판단에 필수 (`origin.repeatingTurn ?? 1`을 starting turn으로 사용)

---

## 5. 이벤트 태그

### 5.1 태그 식별자 (EventTagId)

| 타입 | 설명 |
|---|---|
| `.default` | 기본 태그 (시스템) |
| `.holiday` | 공휴일 태그 (시스템) |
| `.custom(String)` | 사용자 생성 태그 |
| `.externalCalendar(serviceId, calendarId)` | 외부 캘린더 태그 (구글 등) |

### 5.2 태그 CRUD

- **생성**: 이름 + 색상(hex) 지정. 중복 이름 체크 옵션 (`skipCheckDuplicationName`)
- **수정**: 이름/색상 변경
- **삭제**: 빈 태그 삭제 또는 관련 이벤트 일괄 삭제 선택

### 5.3 태그 보이기/숨기기

- 커스텀 태그: 생성 시 기본 **보임**
- 외부 캘린더 태그: 연동 시 기본 **숨김** (사용자가 명시적으로 활성화)
- 숨김 태그 ID 목록은 `offEventTagIdsOnCalendar`로 관리
- 토글/일괄 추가/일괄 제거/서비스별 초기화 지원

### 5.4 색상 결정

| 태그 유형 | 색상 소스 |
|---|---|
| default/holiday | `DefaultEventTagColorSetting`의 hex 값 |
| custom | `CustomEventTag.colorHex` |
| 구글 캘린더 | `GoogleCalendarEventColorSource` (calendarId + 이벤트별 colorId) |

---

## 6. 강조 이벤트 (Foremost Event)

사용자가 가장 중요한 이벤트 **1개**를 지정하는 기능.

- `ForemostEventId`: eventId + isTodo 플래그로 식별
- 캘린더 일별 목록 상단에 고정 표시
- 위젯에서 강조 노출 (`ForemostEventWidget`)
- 지정/해제 시 상태 표시: idle / marking / unmarking
- 위젯에서 할일 완료 토글 가능 (`TodoToggleIntent`)

---

## 7. 알림

### 7.1 알림 시간 옵션

**시간 지정 이벤트용**
| 옵션 | 설명 |
|---|---|
| 정시 (atTime) | 이벤트 시각에 알림 |
| N초 전 (before) | 1분/5분/10분/15분/30분/1시간/2시간/24시간/48시간/168시간 전 |

**하루종일 이벤트용**
| 옵션 | 설명 |
|---|---|
| 당일 9시 (allDay9AM) | 이벤트 당일 오전 9시 |
| 당일 12시 (allDay12AM) | 이벤트 당일 정오 |
| N일 전 9시 (allDay9AMBefore) | 1일/2일/7일 전 오전 9시 |

**커스텀**: `DateComponents`로 자유 지정

### 7.2 알림 정책

- 이벤트당 **복수** 알림 시간 설정 가능
- 기본 알림 시간: 시간 이벤트 / 하루종일 이벤트 별도 설정
- 로컬 알림 스케줄링 범위: 향후 **365일**
- 반복 일정: 각 반복 인스턴스마다 알림 생성
- 이벤트 변경 시: 기존 알림 제거 → 새 알림 등록
- 알림 ID는 DB에 저장하여 추후 제거에 사용
- FCM 푸시 알림: 서버 연동(로그인) 시 토큰 등록

### 7.3 알림 권한

- `UNUserNotificationCenter` 기반 권한 요청
- 상태: `.notDetermined` / `.denied` / `.authorized`
- 설정 화면에서 시스템 알림 설정으로 이동 가능

---

## 8. 구글 캘린더 연동

### 8.1 개요

- **읽기 전용** 연동 (조회만 가능, 편집 불가)
- **다중 계정** 동시 지원
- Google OAuth2로 인증
- 연동 후 캘린더 목록/이벤트/색상 자동 동기화

### 8.2 데이터 모델

| 모델 | 설명 |
|---|---|
| `GoogleCalendar.Colors` | 계정별 캘린더/이벤트 색상 맵 |
| `GoogleCalendar.Tag` | 캘린더 = 태그 (이름, 색상, 소유자) |
| `GoogleCalendar.Event` | 앱용 간소화 이벤트 (ID, 이름, 시간, 색상, 반복) |
| `GoogleCalendar.EventOrigin` | API 원본 (참석자, 회의 링크, 첨부파일, 상태 등 전체) |

### 8.3 연동 플로우

```
OAuth 인증 → 자격증명 저장 → DB 연결 (참조 카운팅)
  → 색상 로드 → 캘린더 목록 로드 → 이벤트 동기화
```

### 8.4 연동 해제 플로우

```
자격증명 삭제 → DB 연결 해제 (ref count 감소)
  → SharedDataStore에서 제거 → 캐시 정리 → 태그 off 상태 정리
```

### 8.5 캘린더 보이기/숨기기

- 구글 캘린더에서 `isSelected != true`인 캘린더는 기본 숨김
- 사용자가 명시적으로 활성화 필요
- 태그 토글로 캘린더별 표시 제어

### 8.6 이벤트 상세 (읽기 전용)

표시 항목: 이벤트명, 시간, 위치, 참석자 목록, 회의 링크, 첨부파일, 설명, 색상, 상태(확정/미정/취소), 공개 범위

"구글 캘린더에서 편집" 버튼 → Safari로 이동

---

## 9. 위젯 (18종)

### 9.1 기본 위젯 (7종)

| 위젯 | 설명 |
|---|---|
| TodayAndNext | 오늘 요약 + 다음 이벤트 |
| Today | 오늘 일정 요약 (완료/미완료 카운트) |
| NextEvent | 다음 예정 이벤트 + 카운트다운 |
| NextRemainEvent | 다음 이벤트 (남은 시간 강조) |
| ForemostEvent | 강조 이벤트 표시 |
| Month | 월 캘린더 그리드 |
| EventList | 다가오는 이벤트 스크롤 목록 (태그 필터) |

### 9.2 주/월 이벤트 위젯 (7종)

| 위젯 | 기간 |
|---|---|
| OneWeekEvents | 7일 |
| TwoWeekEvents | 14일 |
| ThreeWeekEvents | 21일 |
| FourWeekEvents | 28일 |
| CurrentMonthEvents | 이번 달 |
| LastMonthEvents | 지난 달 |
| NextMonthEvents | 다음 달 |

### 9.3 조합 위젯 (4종)

| 위젯 | 구성 |
|---|---|
| TodayAndMonth | 오늘 요약 + 월 캘린더 |
| EventAndMonth | 이벤트 목록 + 월 캘린더 |
| EventAndForemost | 이벤트 목록 + 강조 이벤트 |
| DoubleMonth | 연속 2개월 캘린더 |

### 9.4 위젯 인터랙션

- **할일 완료 토글**: `TodoToggleIntent`로 위젯에서 직접 완료/미완료 전환
- **이벤트 타입 필터**: `EventTypeSelectIntent`로 위젯 표시 내용 필터링
- **딥링크**: 위젯 탭 → `tc.app://` 스킴으로 앱 내 해당 날짜/이벤트로 이동
- **자동 갱신**: 앱 백그라운드 진입 시 `WidgetCenter.reloadAllTimelines()`

### 9.5 위젯 외형 설정

- 배경: 시스템 기본 (`.system`) 또는 커스텀 색상 (`.custom(hex)`)
- App Group을 통한 앱-위젯 데이터 공유

---

## 10. 계정 & 인증

### 10.1 인증 방식

| 방식 | 프로토콜 | 설명 |
|---|---|---|
| 오프라인 (비로그인) | — | 로컬 DB만 사용. 모든 핵심 기능 사용 가능 |
| 구글 로그인 | `GoogleOAuth2ServiceProvider` | OAuth2 → Firebase Auth → 서버 동기화 활성화 |
| 애플 로그인 | `AppleOAuth2ServiceProvider` | Apple Sign In → Firebase Auth → 서버 동기화 활성화 |

**OAuth2 자격증명 모델**

| 제공자 | 자격증명 | 주요 필드 |
|---|---|---|
| Google | `GoogleOAuth2Credential` | idToken, accessToken, refreshToken, accessTokenExpirationDate, email |
| Apple | `AppleOAuth2Credential` | provider(`"apple.com"`), idToken, nonce |

**인증 플로우 상세**

```
사용자 → SignInView → OAuth2ServiceUsecase.requestAuthentication()
                          ↓
                   [Google: Firebase Google Sign-In SDK / Apple: ASAuthorizationController]
                          ↓
                   OAuth2Credential 반환
                          ↓
                   AuthRepository.signIn(credential)
                          ↓
                   Firebase Auth 인증 → Auth(uid, idToken, refreshToken) 획득
                          ↓
                   서버 API로 AccountInfo 로드
                          ↓
                   Auth + AccountInfo → Keychain 저장 (AuthStore)
                          ↓
                   RemoteAPI에 credential 설정
                          ↓
                   Account(auth + info) 반환
```

**Google 추가 스코프**: Google Calendar 연동 시 추가 OAuth2 스코프 요청 가능 (`GoogleOAuth2ServiceProvider.scopes`)

**URL 핸들링**: Google OAuth는 앱 복귀 시 `handle(open url:)` 호출 필요. Apple은 URL 핸들링 불필요.

### 10.2 계정 상태 전환

```
[비로그인] ──로그인──→ [로그인]
    ↑                     │
    └──로그아웃/삭제──────┘
```

**로그인 시** (`AccountUsecaseImple.signIn` → `ApplicationRootViewModel.handleUserSignedIn`):
1. OAuth2 자격증명 획득 (Google/Apple)
2. Firebase Auth 인증 → uid + 토큰 획득
3. 서버에서 AccountInfo 로드 → Keychain 저장
4. SharedDataStore에 AccountInfo 저장
5. `AccountChangedEvent.signedIn` 이벤트 발행
6. `ApplicationPrepareUsecase.prepareSignedIn(auth)`:
   - SharedDataStore 초기화 (accountInfo, externalCalendarAccounts 키는 유지)
   - 비로그인 DB close → 100ms 대기
   - 사용자별 DB open (`todocal_<uid>.db`)
7. `ApplicationRootRouter.changeUsecaseFactroy(auth)`:
   - `LoginUsecaseFactoryImple` 생성 (Remote + Upload 인프라 포함)
   - `backgroundEventSyncUsecase.change(factory:)` 호출
   - `refreshRoot()` → 전체 UI 계층 재구성
8. FCM 토큰 등록
9. 서버 동기화 시작

**로그아웃 시** (`AccountUsecaseImple.signOut` → `ApplicationRootViewModel.handleUserSignedOut`):
1. 사용자 알림 등록 해제
2. Firebase signOut + Keychain에서 Auth/AccountInfo 삭제
3. RemoteAPI credential 해제
4. SharedDataStore 초기화 (externalCalendarAccounts 키만 유지)
5. `AccountChangedEvent.signOut` 이벤트 발행
6. `ApplicationPrepareUsecase.prepareSignedOut()`:
   - 사용자 DB close → 100ms 대기
   - 비로그인 DB open (`todocal.db` — uid 없음)
7. `NonLoginUsecaseFactoryImple`로 전환 → UI 재구성

**계정 삭제 시** (`AccountUsecaseImple.deleteAccount`):
- 로그아웃과 동일 + 서버에 `DELETE /account` API 호출 → 서버 데이터 삭제
- Firebase 계정 삭제

**UsecaseFactory 전환 영향 범위**

| 영역 | NonLogin (비로그인) | Login (로그인) |
|---|---|---|
| Todo Repository | `TodoLocalRepositoryImple` | `TodoUploadDecorateRepositoryImple` (Local + 오프라인 큐) |
| Schedule Repository | Local only | `ScheduleEventUploadDecorateRepositoryImple` |
| EventTag Repository | Local only | `EventTagUploadDecorateRepositoryImple` |
| EventDetail Repository | Local only | `EventDetailUploadDecorateRepositoryImple` |
| ForemostEvent Repository | Local only | `ForemostEventRemoteRepositoryImple` |
| AppSetting Repository | `AppSettingLocalRepositoryImple` | `AppSettingRemoteRepositoryImple` (userId 기반) |
| EventSync Usecase | `NotNeedEventSyncUsecase` (no-op) | `EventSyncUsecaseImple` (실제 동기화) |
| EventUpload Service | `NotNeedEventUploadService` (no-op) | `EventUploadServiceImple` (오프라인 큐) |
| 데이터 마이그레이션 | `NotNeedTemporaryUserDataMigrationUescaseImple` | `TemporaryUserDataMigrationUescaseImple` |

**DB 분리 정책**

| 상태 | DB 경로 | 설명 |
|---|---|---|
| 비로그인 | `todocal.db` | 공용 로컬 DB |
| 로그인 (uid: abc123) | `todocal_abc123.db` | 사용자별 격리 DB |
| 외부 캘린더 | `google_calendar.db` | 서비스별 별도 DB (ExternalCalendarDBConnectionPool) |

### 10.3 데이터 마이그레이션

로그인 전 로컬에 쌓인 데이터를 클라우드로 업로드. `TemporaryUserDataMigrationUescaseImple`이 담당.

**마이그레이션 대상 및 순서**:
1. 이벤트 태그 (EventTag) — 태그가 이벤트에 선행해야 참조 무결
2. 할일 (TodoEvent)
3. 일정 (ScheduleEvent)
4. 이벤트 상세 (EventDetailData)
5. 완료 할일 (DoneTodoEvent)

**UI 상태 Publishers**:
- `isNeedMigration: AnyPublisher<Bool, Never>` — 마이그레이션 필요 여부
- `migrationNeedEventCount: AnyPublisher<Int, Never>` — 마이그레이션 필요 건수 (ManageAccount 화면에 표시)
- `isMigrating: AnyPublisher<Bool, Never>` — 진행 중 로딩 표시
- `migrationResult: AnyPublisher<Result<Void, Error>, Never>` — 완료/실패 결과

**동기화와의 조율**: `EventSyncMediator`가 마이그레이션 진행 중에는 서버 동기화를 대기시킴 (`isTemporaryUserDataMigration` 플래그 확인).

**마이그레이션 소스 경로**: `LoginUsecaseFactoryImple` 생성 시 `temporaryUserDataFilePath`로 비로그인 DB 경로 전달 → 해당 DB에서 데이터 읽기.

**앱 재시작 시 복원**: 마이그레이션이 중간에 중단되면 다음 앱 실행 시 `ManageAccountViewModel.prepare()`에서 다시 체크하여 재시도 유도.

---

## 11. 동기화

### 11.1 오프라인 우선 아키텍처

```
[사용자 액션] → LocalRepository (즉시 저장 → UI 즉시 반영)
                    ↓
              UploadDecorateRepository (로컬 저장 + 오프라인 큐에 태스크 추가)
                    ↓
              EventUploadServiceImple (Actor, 큐에서 pop → 업로드 시도)
                    ↓
              RemoteRepository (서버 전송)
```

- 비로그인: `LocalRepository`만 사용. Remote/Upload 계층 없음.
- 로그인: `UploadDecorateRepository`가 로컬 저장과 동시에 업로드 큐에 태스크 추가.

**Decorator별 큐잉 동작**

| Decorator | 생성 시 큐 | 수정 시 큐 | 삭제 시 큐 |
|---|---|---|---|
| `TodoUploadDecorateRepositoryImple` | `.todo` | `.todo` | `.todo(remove)` + `.eventDetail(remove)` |
| Todo 완료 시 | — | `.todo` + `.doneTodo` + `.doneTodoDetail` | — |
| `ScheduleEventUploadDecorateRepositoryImple` | `.schedule` | `.schedule` | `.schedule(remove)` + `.eventDetail(remove)` |
| `EventTagUploadDecorateRepositoryImple` | `.eventTag` | `.eventTag` | `.eventTag(remove)` |
| `EventDetailUploadDecorateRepositoryImple` | `.eventDetail` | `.eventDetail` | `.eventDetail(remove)` |

### 11.2 서버 동기화

| 항목 | 내용 |
|---|---|
| 동기화 대상 | `EventTag`, `TodoEvent`, `ScheduleEvent` (3가지 `SyncDataType`) |
| 페이지 크기 | 30건/요청 (`pageSize` 상수) |
| 방식 | 타임스탬프 기반 증분 동기화 (밀리초 단위 정수) |
| 페이지네이션 | 커서 기반 (서버가 `nextPageCursor` 반환) |
| 타임스탬프 저장 | `SyncTimestamp` SQLite 테이블 (data_type별 독립 관리) |

**API 엔드포인트**

| 단계 | 메서드 | 경로 | 파라미터 |
|---|---|---|---|
| 체크 | GET | `/v1/sync/check` | `dataType`, `timestamp` (optional) |
| 시작 | GET | `/v1/sync/start` | `dataType`, `timestamp` (optional), `size` (30) |
| 계속 | GET | `/v1/sync/continue` | `dataType`, `cursor`, `size` |

**동기화 체크 응답** (`EventSyncCheckRespose`)

| 응답 (`CheckResult`) | 동작 |
|---|---|
| `.noNeedToSync` | 해당 데이터 타입 건너뛰기 |
| `.needToSync` | 서버가 반환한 `startTimestamp`부터 증분 동기화 |
| `.migrationNeeds` | 타임스탬프 무시, 처음부터 전체 동기화 |

**동기화 응답 구조** (`EventSyncResponse<T>`)

```swift
struct EventSyncResponse<T: Sendable> {
    var created: [T]?        // 새로 생성된 항목
    var updated: [T]?        // 수정된 항목
    var deletedIds: [String]? // 삭제된 항목 ID
    var nextPageCursor: String? // 다음 페이지 커서 (nil이면 마지막 페이지)
    var newSyncTime: Int?    // 다음 체크에 사용할 타임스탬프
}
```

**동기화 실행 순서** (`EventSyncUsecaseImple.runSyncTask`):
1. `EventSyncMediator.waitUntilEventSyncAvailable()` — 업로드 큐 비움 + 마이그레이션 대기
2. EventTag 동기화 (check → start → continue 루프)
3. Todo 동기화
4. Schedule 동기화
5. 각 타입은 독립적으로 에러 처리 (한 타입 실패해도 나머지 계속)

**충돌 해결 전략**: **서버 우선 (Last-Write-Wins)**
- 클라이언트는 충돌 감지 없음 (엔티티에 버전 번호 없음)
- 동기화 응답의 `created`/`updated` 항목이 로컬을 덮어씀 (`updateCreatedOrUpdated()`)
- `EventSyncMediator`가 업로드 완료 후 동기화를 시작하여 순서 보장: 로컬 변경 → 서버 전송 → 서버 상태 pull

### 11.3 오프라인 큐

**저장소**: `event_upload_pending_queue` SQLite 테이블

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `timestamp` | REAL | 큐잉 시각 (FIFO 정렬 기준) |
| `data_type` | TEXT | 데이터 타입 (eventTag/todo/schedule/eventDetail/doneTodo/doneTodoDetail) |
| `uuid` | TEXT | 엔티티 ID |
| `is_remove` | INTEGER | 0: 생성/수정, 1: 삭제 |
| `upload_fail_count` | INTEGER | 재시도 횟수 (기본 0) |

- 복합 PK: `(uuid, data_type)` → 같은 엔티티의 중복 큐잉 시 upsert
- 정렬: `timestamp` 오름차순 (FIFO)

**처리 흐름** (`EventUploadServiceImple` — Swift Actor):
1. `append(tasks)` → SQLite 큐에 upsert → `resume()` 호출
2. `resume()`:
   - `isUploading = true`
   - `popTask()`: `upload_fail_count < maxFailCount`인 가장 오래된 태스크 pop
   - `uploadTask()`: Remote API 호출
   - 성공 → 큐에서 삭제
   - 실패 → `upload_fail_count + 1`로 재큐잉 (타임스탬프 갱신)
   - 큐가 빌 때까지 반복
   - `isUploading = false`
3. `pause()`: 현재 배치 취소

**재시도 정책**:
- 최대 재시도: **10회** (`AppEnvironment.eventUploadMaxFailCount`)
- 재시도 간격: 즉시 (큐에서 다시 pop될 때). 별도 지수 백오프 없음.
- 10회 초과 시: 큐에 남아있으나 pop 대상에서 제외. 다음 동기화 사이클이나 강제 동기화로 처리.

**업로드 엔드포인트**

| 데이터 타입 | 생성/수정 | 삭제 |
|---|---|---|
| EventTag | `PUT /v2/tags/{tagId}` | `DELETE /v2/tags/{tagId}` |
| Todo | `POST/PUT /v2/todos/{todoId}` | `DELETE /v2/todos/{todoId}` |
| Schedule | `PUT /v2/schedules/{eventId}` | `DELETE /v2/schedules/{eventId}` |
| EventDetail | `POST /v1/event_details/{eventId}` | `DELETE /v1/event_details/{eventId}` |

### 11.4 백그라운드 동기화

`BackgroundEventSyncUsecaseImple`이 iOS 백그라운드 작업을 관리.

**등록** (`registerTask()`):
- 식별자: `"com.sudo.park.TodoCalendarApp.bgSync"`
- 타입: `BGAppRefreshTask`
- 시점: `AppDelegate.application(didFinishLaunchingWithOptions:)`에서 호출

**스케줄링** (`scheduleTask()`):
- `BGAppRefreshTaskRequest` 생성
- `earliestBeginDate`: 다음 정시 55분 전 (≈ 매시간 1회)

**실행** (`handleBackgroundSync(task)`):
1. `UIApplication.beginBackgroundTask()` → 확장 실행 시간 확보
2. `expirationHandler` 설정 → 타임아웃 시 다음 사이클로 재스케줄링
3. `runSync()` → `eventSyncUsecase.sync()` 실행
4. 동기화 완료 → `WidgetCenter.shared.reloadAllTimelines()` (위젯 갱신)
5. 태스크 완료 마킹 + 다음 스케줄 등록

**시스템 제약**:
- iOS가 실행 빈도를 앱 사용 패턴에 따라 자동 조절 (빈도 보장 없음)
- 배터리 저전력 모드 시 실행 연기 가능
- 네트워크 상태는 별도 체크하지 않음 (Alamofire가 네트워크 에러 반환 시 업로드 실패 → 재시도)

### 11.5 강제 동기화

- `EventSyncUsecase.forceSync()`: 모든 `SyncDataType`의 타임스탬프 초기화 (`clearSyncTimestamp()`) → 전체 재동기화
- 설정 화면에서 수동 트리거 가능
- 동기화 진행 상태: `isSyncInProgress: AnyPublisher<Bool, Never>`로 UI에 표시

---

## 12. 설정

모든 설정은 `EnvironmentStorage` (UserDefaults 래퍼)에 저장되며, Usecase가 SharedDataStore에 publish하여 구독 중인 모든 화면에 실시간 반영된다.

### 12.1 캘린더 외형 설정

`CalendarAppearanceSettings` — UserDefaults 키별 저장.

| 설정 | UserDefaults 키 | 옵션 | 기본값 |
|---|---|---|---|
| 첫째 요일 | Repository (SQLite) | 일~토 | `.sunday` |
| 이벤트 있는 날 밑줄 | `show_underline_eventday` | on/off | `true` |
| 행 높이 | `calendar_row_height` | 소/중/대 | `.medium` (rawValue: 0) |
| 캘린더 내 이벤트 텍스트 크기 | `event_on_calendar_additional_font_size` | CGFloat 조절 | `0` |
| 캘린더 내 이벤트 볼드 | `bold_text_event_on_calendar` | on/off | `false` |
| 캘린더 내 태그 색상 표시 | `not_show_event_tag_color_on_calendar` | on/off | `false` (반전 키: 표시=true) |
| 이벤트 목록 텍스트 크기 | `event_additiona_font_size` | CGFloat 조절 | `0` |
| 공휴일 이름 표시 | `show_holiday_name_on_eventList` | on/off | `false` |
| 음력 날짜 표시 | `show_lunar_calendar_date` | on/off | `false` |
| 12/24시간 표시 | `is_24_hourForm` | 12h/24h | `true` (24시간) |
| 미완료 할일 상단 표시 | `hide_uncompleted_todos` | on/off | `false` (반전 키: 표시=true) |
| 햅틱 피드백 | `haptic_effect_off` | on/off | `false` (반전 키: 켜짐=false) |
| 애니메이션 효과 | `animation_effect_on` | on/off | `false` |
| 공휴일 강조 (색상) | `accent_holiday` | on/off | `false` |
| 토요일 강조 (색상) | `accent_saturday` | on/off | `false` |
| 일요일 강조 (색상) | `accent_sunday` | on/off | `false` |

**실시간 반영 흐름**:
```
사용자 변경 → AppSettingUsecase.changeCalendarAppearanceSetting()
    → EnvironmentStorage(UserDefaults) 저장
    → SharedDataStore.put(CalendarAppearanceSettings)
    → CalendarViewModel 등 구독자가 Combine으로 수신 → UI 즉시 갱신
```

**영향받는 화면 매트릭스**

| 설정 변경 | 캘린더 그리드 | 이벤트 목록 | 위젯 |
|---|---|---|---|
| 첫째 요일 | ✅ 그리드 재구성 | — | ✅ 주/월 위젯 |
| 행 높이 | ✅ 셀 높이 + "+N" 재계산 | — | — |
| 이벤트 텍스트 크기/볼드 | ✅ 이벤트 바 폰트 | — | — |
| 태그 색상 표시 | ✅ 색상 바 표시/숨김 | — | — |
| 목록 텍스트 크기 | — | ✅ 셀 폰트 | — |
| 공휴일 표시 | ✅ 공휴일 강조 | ✅ 날짜 정보 섹션 | ✅ |
| 음력 표시 | — | ✅ 날짜 정보 섹션 | — |
| 미완료 할일 | — | ✅ 섹션 표시/숨김 | — |
| 컬러 테마 | ✅ 전체 | ✅ 전체 | ✅ 전체 |

### 12.2 이벤트 기본값 설정

`EventSettings` — UserDefaults 키별 저장.

| 설정 | UserDefaults 키 | 옵션 | 기본값 |
|---|---|---|---|
| 기본 이벤트 길이 | `default_new_event_period` | 0분/5분/10분/15분/30분/45분/1시간/2시간/하루종일 | `.minute0` |
| 기본 태그 | `default_new_event_tagId` | 태그 선택 | `.default` |
| 기본 알림 (시간 이벤트) | 별도 저장 | 알림 시간 옵션 선택 | — |
| 기본 알림 (하루종일) | 별도 저장 | 알림 시간 옵션 선택 | — |
| 기본 지도 앱 | `default_map_app` | Apple Maps / Google Maps / Naver / Kakao | `nil` (선택 안 함) |

이벤트 생성 화면 진입 시 `EventSettings`에서 기본값을 읽어 초기 필드를 채움.

### 12.3 공휴일 설정

- 국가 선택 (디바이스 지역 코드 기반 자동 선택)
- 연도별 공휴일 lazy 로딩 (요청 시점에 API 호출 → 캐시)
- 캐시: `[countryCode][year][holidays]` 중첩 구조 (SharedDataStore `holidays` 키)
- 12월 → 다음해, 1월 → 전년도 공휴일도 함께 로드 (캘린더 3개월 윈도우 대응)
- 국가 변경 시 기존 캐시 초기화 → 새 국가 공휴일 재로드

### 12.4 타임존 설정

- 기본: `TimeZone.current` (시스템 타임존)
- 전체 타임존 목록에서 선택 (Repository에 SQLite 저장)
- SharedDataStore `timeZone` 키로 전파
- 하루종일 이벤트는 타임존에 따라 `Range<TimeInterval>.shiftting()` 적용:
  ```
  원본(이벤트 타임존) → UTC로 변환 → 대상 타임존으로 변환
  ```
- D-Day 계산, 이벤트 목록 정렬, 알림 fire date 모두 현재 설정 타임존 기준

### 12.5 컬러 테마

사용 가능 (`color_set` 키): `systemTheme` (시스템 따라감), `defaultLight`, `defaultDark`

테마 변경 시 `ViewAppearance` 전체가 갱신 → 모든 화면 즉시 반영.

### 12.6 기본 태그 색상

| 태그 | UserDefaults 키 | 기본값 |
|---|---|---|
| 기본(default) 태그 | `default_tag_color` | `"#088CDA"` (파란색) |
| 공휴일(holiday) 태그 | `holiday_tag_color` | `"#D6236A"` (분홍색) |

색상 변경 시 SharedDataStore `defaultEventTagColor` 키로 전파 → 캘린더, 이벤트 목록, 위젯 모두 반영.

---

## 13. 공유 상태 관리 (SharedDataStore)

모든 Usecase가 하나의 `SharedDataStore` 싱글톤을 통해 상태를 공유. Combine 기반 실시간 전파.

### 13.1 구현 상세

```swift
public final class SharedDataStore: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var memorizedDataSubjects: [String: CurrentValueSubject<Any?, Never>] = [:]
    private let serialEventQeueu: DispatchQueue?
}
```

**스레드 안전성**:
- `NSRecursiveLock`으로 모든 `memorizedDataSubjects` 접근 보호
- 모든 public 메서드에서 `lock.lock(); defer { lock.unlock() }` 패턴
- `@unchecked Sendable` — 수동 스레드 안전 보장

**메모리 관리**:
- Subject는 키별 lazy 생성: 첫 `observe()` 또는 `put()` 시 `CurrentValueSubject` 생성
- 한번 생성된 Subject는 영구 유지 (구독자 수와 무관)
- `clearAll(filter:)`: 조건에 맞는 키의 Subject 값을 nil로 설정 (Subject 자체는 유지)

**Combine API**:

| 메서드 | 동작 |
|---|---|
| `observe<V>(type, key)` → `AnyPublisher<V?, Never>` | 현재 값 즉시 방출 + 변경 시 push. Optional serial queue 전달. |
| `put<V>(type, key, value)` | Subject에 값 설정 (즉시 구독자에게 전파) |
| `update<V>(type, key, mutating:)` | 현재 값을 읽어 변환 후 put (atomic update) |
| `value<V>(type, key)` → `V?` | 동기적 현재 값 읽기 |
| `clearAll(filter:)` | 조건부 전체 초기화 |

### 13.2 주요 키

| 키 | 타입 | 관리 주체 |
|---|---|---|
| `accountInfo` | `AccountInfo?` | AccountUsecase |
| `todos` | `[String: TodoEvent]` | TodoEventUsecase |
| `uncompletedTodos` | `[TodoEvent]` | TodoEventUsecase |
| `schedules` | `MemorizedEventsContainer<ScheduleEvent>` | ScheduleEventUsecase |
| `tags` | `[EventTagId: any EventTag]` | EventTagUsecase |
| `offEventTagSet` | `Set<EventTagId>` | EventTagUsecase |
| `defaultEventTagColor` | `[EventTagId: String]` | EventTagUsecase |
| `foremostEventId` | `ForemostEventId` | ForemostEventUsecase |
| `foremostMarkingStatus` | `ForemostMarkingStatus` | ForemostEventUsecase |
| `googleCalendarTags` | `[String: [GoogleCalendar.Tag]]` | GoogleCalendarUsecase |
| `googleCalendarEvents` | `[String: GoogleCalendar.Event]` | GoogleCalendarUsecase |
| `externalCalendarAccounts` | `[String: [ExternalServiceAccountinfo]]` | ExternalCalendarIntegrationUsecase |
| `calendarAppearance` | `CalendarAppearanceSettings` | UISettingUsecase |
| `eventSetting` | `EventSettings` | EventSettingUsecase |
| `timeZone` | `TimeZone` | CalendarSettingUsecase |
| `firstWeekDay` | `DayOfWeeks` | CalendarSettingUsecase |
| `currentCountry` | `String` | HolidayUsecase |
| `availableCountries` | `[String]` | HolidayUsecase |
| `holidays` | `[Int: [Holiday]]` | HolidayUsecase |

**로그인/로그아웃 시 초기화 범위**:

| 전환 | 초기화 범위 | 유지 키 |
|---|---|---|
| 로그인 | 대부분 초기화 | `accountInfo`, `externalCalendarAccounts` |
| 로그아웃 | 전체 초기화 | `externalCalendarAccounts` |

### 13.3 화면 간 통신

| 방향 | 메커니즘 | 용도 |
|---|---|---|
| 간접 공유 | SharedDataStore (Usecase 경유) | 같은 데이터를 구독하는 독립 화면 간 |
| Parent → Child | Interactor | 부모가 자식에게 명령 |
| Child → Parent | Listener (weak) | 자식이 부모에게 이벤트 전달 |

**간접 공유 예시**: 이벤트 상세 화면에서 할일 완료 → `TodoEventUsecase`가 SharedDataStore의 `todos` 업데이트 → 캘린더 그리드, 이벤트 목록, 위젯이 각각 독립적으로 변경 수신.

---

## 14. 딥링크

### 14.1 URL 스펙

| 항목 | 값 |
|---|---|
| 스킴 | `tc.app` (`AppEnvironment.appScheme`) |
| 호스트 | `calendar` |
| 처리 | `ApplicationDeepLinkHandlerImple` |

**지원 딥링크 형식**

| 용도 | URL 패턴 | 쿼리 파라미터 |
|---|---|---|
| 날짜 이동 | `tc.app://calendar/?select=YYYY_MM_DD` | `select`: `year_month_day` 형식 |
| 이벤트 상세 | `tc.app://calendar/event/?id=<eventId>&type=<eventType>` | `id`, `type` |

### 14.2 딥링크 처리 구조

```
URL 수신 (앱 실행 / 위젯 탭)
    ↓
PendingDeepLink 파싱:
    - URLComponents로 scheme, host, path, queryItems 추출
    - pathComponents: "/" 기준 분할
    - queryParams: percent-decoding 적용
    ↓
ApplicationDeepLinkHandlerImple:
    - scheme == "tc.app" 확인
    - host별 라우팅:
        └── "calendar" → CalendarDeepLinkHandlerImple
            ├── path에 "event" → EventDeepLinkHandlerImple
            └── path 없음 → handleMoveDate() (날짜 이동)
    ↓
미지원 링크 → .needUpdate → 앱 업데이트 안내 다이얼로그
```

**Pending 링크 처리**:
- 대상 핸들러가 아직 초기화되지 않은 경우 `pendingCalendarLink`에 보관
- 핸들러 초기화 시 `attach()` 호출 → 보관된 링크 즉시 처리

---

## 15. 피드백

### 15.1 입력 데이터

| 필드 | 필수 | 설명 |
|---|---|---|
| 연락처 이메일 | 선택 | 사용자 입력 |
| 피드백 메시지 | 필수 | 사용자 입력 |

### 15.2 자동 수집 데이터

| 필드 | 소스 |
|---|---|
| userId | 현재 로그인 사용자 ID (비로그인 시 `"null"`) |
| osVersion | `UIDevice` (예: `"18.3.1"`) |
| appVersion | `Bundle.main` (예: `"1.0.0"`) |
| deviceModel | `UIDevice` (예: `"iPhone 15"`) |
| isIOSAppOnMac | `ProcessInfo` Mac Catalyst 여부 |

### 15.3 전송 방식

`FeedbackRepositoryImple` → `FeedbackEndpoints.post` (서버 API)

**페이로드 형식**: Slack Incoming Webhook JSON

```json
{
  "attachments": [{
    "fallback": "incomming cs from: <email>",
    "pretext": "incomming cs from: <email>",
    "color": "good",
    "fields": [
      { "title": "message", "value": "사용자 메시지" },
      { "title": "user id", "value": "abc123" },
      { "title": "os version", "value": "18.3.1" },
      { "title": "app version", "value": "1.0.0" },
      { "title": "device model", "value": "iPhone 15" },
      { "title": "is ios app on Mac?", "value": "false" }
    ]
  }]
}
```

피드백 전송은 async/await 기반. Usecase에서 DeviceInfo 수집 → FeedbackMakeParams 조립 → Repository 전송.

---

## 16. 미완료 할일 정책

**정의**: `time?.upperBoundWithFixed > 현재시각`인 할일

**자동 관리**:
- 시간을 미래로 설정 → 자동 추가
- 시간을 과거로 변경 / 시간 제거 → 자동 제거
- 완료/삭제 → 자동 제거
- 캘린더 메인 화면에서 별도 섹션으로 표시

---

## 17. D-Day 카운트다운

`DaysIntervalCountUsecase` — 이벤트/공휴일까지 남은 일수를 실시간 계산.

### 17.1 계산 공식

```
1. 현재 시각(Date)과 대상 시각(Date)을 Gregorian Calendar로 가져옴
2. Calendar의 timeZone을 현재 설정 타임존으로 설정
3. 양쪽 모두 startOfDay()로 00:00:00 정규화
4. dateComponents([.day], from:to:).day → 일수 차이 (Int)
```

**예시**:
- 현재: 2025-03-31 14:30 → 정규화: 2025-03-31 00:00
- 대상: 2025-04-05 09:15 → 정규화: 2025-04-05 00:00
- 결과: **5일** (양수 = 미래, 음수 = 과거)

### 17.2 타임존 처리

- `Calendar(identifier: .gregorian)`에 `CalendarSettingUsecase.currentTimeZone` 적용
- 사용자가 타임존을 변경하면 D-Day 값도 즉시 재계산
- 하루종일 이벤트의 경우 `Range<TimeInterval>.shiftting(secondsFromGMT:to:)` 변환 후 대상 날짜 결정

**하루종일 이벤트 타임존 변환**:
```
원본 범위 (이벤트 타임존) → +secondsFromGMT → UTC 범위 → -targetTimeZone.secondsFromGMT → 대상 타임존 범위
```

### 17.3 실시간 업데이트

- 1초 간격 타이머 (`secondTicks`) + 타임존 변경 Publisher를 `CombineLatest`
- `removeDuplicates()`: 일수가 실제로 변경될 때만 UI 갱신
- 사용 화면: 공휴일 상세, 이벤트 상세 등

---

## 18. DB 마이그레이션

### 18.1 메인 DB (`todo_calendar.db`)

**현재 버전**: `AppEnvironment.dbVersion = 6`

**마이그레이션 메커니즘** (`SQLiteService`):
1. 앱 시작 시 `AppDataMigrationImple.runDBMigration()` 호출
2. `mainDB.async.migrate(upto: dbVersion, steps:finalized:)`
3. SQLite `user_version` pragma로 현재 버전 확인
4. 현재 → 목표까지 1단계씩 순차 실행
5. 각 단계에서 `Table.migrateStatement(for: version)` → SQL 실행
6. 성공 시 `user_version` 증가
7. 최종 단계 후 `finalized` 콜백 (WAL 모드 설정)

**버전별 변경 이력**

| 버전 | 변경 내용 | 영향 테이블 | SQL |
|---|---|---|---|
| 0→1 | 반복 종료 횟수 컬럼 추가 | `TodoEvents`, `Schedules`, `PendingDoneTodoEvent` | `ALTER TABLE ... ADD COLUMN repeating_count INTEGER` |
| 1→2 | 구글 캘린더 이벤트 상태 컬럼 | `google_calendar_event_origin` (레거시) | `ALTER TABLE ... ADD COLUMN status TEXT` |
| 2→3 | 구글 캘린더 태그 선택 컬럼 | `google_calendar_list` (레거시) | `ALTER TABLE ... ADD COLUMN is_selected INTEGER` |
| 3→4 | 구글 캘린더 이벤트 가시성 컬럼 | `google_calendar_event_origin` (레거시) | `ALTER TABLE ... ADD COLUMN visibility TEXT` |
| 4→5 | 업로드 큐 테이블 재구성 | `event_upload_pending_queue` | 임시 테이블 생성 → 데이터 이동 → 원본 삭제 → 이름 변경 |
| 5→6 | 할일 반복 회차 컬럼 추가 | `TodoEvents` | `ALTER TABLE ... ADD COLUMN repeating_turn INTEGER` |

**전체 테이블 목록** (`prepareTables()` 순서):

1. `KeyValueTable`
2. `HolidayTable`
3. `EventTimeTable`
4. `EventDetailDataTable`
5. `CustomEventTagTable`
6. `ScheduleEventTable`
7. `EventSyncTimestampTable`
8. `DoneTodoEventTable`
9. `DoneTodoEventDetailTable`
10. `PendingDoneTodoEventTable`
11. `TodoEventTable`
12. `TodoToggleStateTable`
13. `EventUploadPendingQueueTable`
14. `EventNotificationIdTable`

### 18.2 실패 처리 전략

**테이블별 개별 try-catch**:
- 각 테이블 마이그레이션이 독립적으로 에러 처리
- 마이그레이션 실패 시 → 해당 테이블 drop → 다음 앱 실행의 `prepareTables()`에서 재생성 (데이터 손실 감수)

**버전별 에러 강도**:

| 버전 | 에러 처리 | 이유 |
|---|---|---|
| 0→1, 1→2, 2→3, 3→4 | `try` (hard fail) | 핵심 스키마 변경 |
| 4→5, 5→6 | `try?` (soft fail) | 큐 재구성/부가 컬럼, 실패해도 앱 동작에 큰 영향 없음 |

**전체 실패 시**: 최상위 try-catch에서 에러 로깅만 수행, 앱 크래시 방지.

### 18.3 외부 캘린더 DB (`google_calendar.db`)

**현재 버전**: `AppEnvironment.googleCalendarDBVersion = 0`

- DB 연결은 `ExternalCalendarDBConnectionPool`이 관리 (참조 카운팅, lazy open)
- `onFirstOpen` 시 테이블 생성 + 마이그레이션 실행
- 현재 v0이므로 마이그레이션 없음 (모든 테이블이 최신 스키마로 생성)

**테이블**: `GoogleCalendarColorsTable`, `GoogleCalendarEventOriginTable`, `GoogleCalendarEventTagTable` — 모두 `account_id` 컬럼으로 다중 계정 지원.

### 18.4 레거시 데이터 이관

구글 캘린더 데이터가 메인 DB(레거시 테이블)에서 별도 DB로 이동하는 일회성 마이그레이션:
- 플래그: `"google_calendar_migrated"` (한번 실행 후 스킵)
- DB Pool 연결이 없으면 스킵 (플래그 미설정 → 다음에 재시도)
- 읽기/쓰기 실패 시 soft fail (`try?`) → 플래그는 설정하여 재시도 방지

### 18.5 새 마이그레이션 추가 절차

1. `AppEnvironment.dbVersion` (또는 `googleCalendarDBVersion`) 증가
2. 해당 `Table` 타입의 `migrateStatement(for version:)`에 새 case 추가
3. `AppDataMigrationImple.runDBMigration()`의 switch에 새 version case 추가
4. 두 곳을 반드시 함께 변경해야 마이그레이션이 실행됨

---

## 19. 주요 외부 의존성

| 라이브러리 | 버전 | 용도 | 빌드 타입 |
|---|---|---|---|
| Alamofire | 5.7.1 | HTTP 클라이언트 (Remote API) | dynamic framework |
| Kingfisher | 7.10.0 | 이미지 캐싱 & 다운로드 | dynamic framework |
| swift-prelude | main | 함수형 프로그래밍 연산자 (`\|>`, `.~` 렌즈) | dynamic framework |
| swift-async-algorithms | 0.1.0 | Async sequence 연산 | dynamic framework |
| publisher-async-bind | 0.0.2 | Combine ↔ async/await 브릿지 | dynamic framework |
| SQLiteService | 0.2.0 | SQLite DB 래퍼 (Table 프로토콜, 마이그레이션) | dynamic framework |
| CombineCocoa | 0.4.1 | UIKit + Combine 확장 | dynamic framework |
| Pulse | 4.0.3 | 네트워크 로깅 & 디버깅 | dynamic framework |
| Firebase (Messaging) | — | 푸시 알림 (FCM 토큰 등록/해제) | — |
| AppAuth | — | Google OAuth2 인증 플로우 | — |
| Combine | 시스템 | 반응형 스트림 (메인 상태 관리) | 시스템 프레임워크 |

**의존성 관리**: Tuist v3 + SPM. `Tuist/Dependencies.swift`에서 모든 외부 패키지 선언. 모두 dynamic framework로 컴파일.
