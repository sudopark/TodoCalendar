---
name: run-tests
description: Use when the user wants to run tests for the TodoCalendar project - runs all or specific test schemes via the project's test script
---

# Run Tests — TodoCalendar

`scripts/run-all-tests.sh`를 실행하여 프로젝트 테스트를 돌린다.

## Usage

```bash
# 전체 테스트
./scripts/run-all-tests.sh

# 특정 스킴만
./scripts/run-all-tests.sh Domain Repository

# destination 오버라이드
DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.0' ./scripts/run-all-tests.sh
```

## 시뮬레이터

`DESTINATION` 을 안 주면 `scripts/ensure-test-simulator.sh` 가 **iPhone 16 / iOS 18.0** 을
확보해 UDID 로 넘긴다 — 없으면 만든다. CI(`pr_test.yml`)도 같은 스크립트를 부르므로
로컬과 CI 의 실행 기기가 갈리지 않는다.

기기·OS 를 바꿔야 하면 그 스크립트 한 곳만 고친다. 촬영 기준(snapshot-check §3 — iPhone 17
/ iOS 26.2)과는 별개다 — 스냅샷은 시뮬 상태에 의존해 전용기를 따로 쓴다.

## Available Schemes

`Extensions` / `Domain` / `Repository` / `AuthService` / `BillingScenes` / `CalendarScenes` / `EventDetailScene` / `EventListScenes` / `SettingScene` / `MemberScenes` / `AIAgentScene` / `TodoCalendarApp` / `TodoCalendarAppWidget` / `TodoCalendarAppShare`

이 목록이 문서 쪽 스킴 목록의 **정본**이다 (CLAUDE.md §3에서 이관). 신규 스킴 등록 절차는 add-framework 스킬.

## Instructions

1. 프로젝트 루트(`/Users/sudo.park/Documents/codebase/TodoCalendar`)에서 실행
2. 인자 없이 실행하면 14개 스킴 전체 순차 실행
3. 실패 시 `FAILED` 스킴 목록과 상위 에러 라인 출력
4. 빌드 실패(`BUILD FAILED`)도 FAILED로 판정됨

## Invoke

```bash
cd /Users/sudo.park/Documents/codebase/TodoCalendar && ./scripts/run-all-tests.sh
```

## 종료 기록 — skill_end

**유저가 이 스킬을 직접 호출한 독립 런에서만** 남긴다. 결과 판정(PASS 스킴 / FAILED 스킴 + 상위 에러 라인)을 보고한 직후 `log-record.py skill_end --name run-tests` (명령·compliance 규칙은 CLAUDE.md §1). 실패가 났어도 판정을 보고했으면 이 스킬의 절차는 끝난 것이다 — 후속 수정은 troubleshoot·implement 소관이다.

**다른 스킬 안에서 도구로 호출된 경우는 기록하지 않는다** — implement 완료 판정의 스킴 실행, 페어 wrap-up의 검증 등. 런을 마무리하는 전이는 호출한 스킬 쪽이고 종료 레코드도 거기서 남는다. 여기서 또 남기면 한 런에 종료가 두 겹으로 쌓여 호출 스킬의 준수 신호와 섞인다.

종속 호출로 뜨는 구조적 누락률은 `usage-thresholds.json`의 `missing_rate_exempt_skills`로 처리한다 — 누락률 숫자를 근거로 위 기록 범위를 넓히지 않는다.
