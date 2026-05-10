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
DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.1' ./scripts/run-all-tests.sh
```

## Available Schemes

`Domain` / `Repository` / `CalendarScenes` / `EventDetailScene` / `EventListScenes` / `SettingScene` / `MemberScenes` / `TodoCalendarApp` / `TodoCalendarAppWidget`

## Instructions

1. 프로젝트 루트(`/Users/sudo.park/Documents/codebase/TodoCalendar`)에서 실행
2. 인자 없이 실행하면 9개 스킴 전체 순차 실행
3. 실패 시 `FAILED` 스킴 목록과 상위 에러 라인 출력
4. 빌드 실패(`BUILD FAILED`)도 FAILED로 판정됨

## Invoke

```bash
cd /Users/sudo.park/Documents/codebase/TodoCalendar && ./scripts/run-all-tests.sh
```
