# Troubleshooting Index

버그·논리 모순의 규명 결과와 결정된 해결책 아카이브. 조회·기록 절차와 레코드 템플릿은 `.claude/skills/troubleshoot/SKILL.md`.

한 줄 포맷: `- [YYYY-MM-DD 제목](파일.md) — 서브도메인 / resolution(fixed|workaround|deferred|non-issue) / 증상 키워드`

<!-- 레코드는 아래에 최신순으로 추가 -->

- [2026-08-16 구글 이벤트의 시간 표현을 바꾸면 `Invalid start time` 400 이 뜬다](2026-08-16-google-event-time-type-switch-invalid-start-time.md) — ExternalCalendar / fixed / Invalid start time, 구글 이벤트 종일 전환 400, date dateTime 공존, patch 병합

- [2026-08-09 종료조건이 n회인 반복 할일이 n회를 훌쩍 넘겨서까지 반복된다](2026-08-09-repeating-todo-count-end-not-working.md) — Event / fixed / 반복 todo count 종료 안됨, 종료조건 n회 초과 반복, repeatingTurn 유실, 업로드 후 turn 리셋

- [2026-08-09 중지를 눌러도 서버에 cancel이 안 나가고, 중지한 job의 결과가 뒤늦게 뜬다](2026-08-09-ai-job-stop-not-reaching-server.md) — AIAgent / fixed / 중지 안됨, 중지 후 완료 푸시, 복귀 시 진행중 안보임, 결과 시트 뒤늦게 노출, Combine throttle 지연

- [2026-08-08 run-all-tests.sh가 컴파일 실패를 PASSED로 보고한다](2026-08-08-run-all-tests-reports-compile-failure-as-passed.md) — Infra / fixed / PASSED 오보, 컴파일 에러인데 통과, TEST FAILED 미감지, Executed 0 tests

- [2026-08-07 비반복 이벤트를 롱탭했는데 컨텍스트 메뉴에 "이번만 삭제"가 뜬다](2026-08-07-day-event-list-context-menu-shows-wrong-remove-action.md) — Event / fixed / 이번만 삭제 오노출, 메뉴 깜빡임, 탭 무반응, 셀 목록 재방출

- [2026-08-07 키보드 입력 시트에서 커맨드를 전송하면 present 충돌로 크래시](2026-08-07-ai-command-sheet-present-while-keyboard-sheet-up.md) — AIAgent / fixed / already presenting, 바텀시트 크래시, 키보드 입력 전송
- [2026-08-06 Share Extension으로 만든 AI job의 결과 푸시가 안 온다](2026-08-06-share-extension-ai-job-no-push.md) — AIAgent / non-issue / 푸시 안옴, device_id, DailyLimitExceeded, share extension
- [2026-08-15 공유 미리보기에 조회 범위와 안 겹치는 이벤트가 섞여 나온다](2026-08-15-share-preview-shows-events-outside-range.md) — Event / fixed / 범위 밖 이벤트 노출·반복 일정 turn·clamped 재판정 누락

- [2026-08-16 공유 미리보기에서 일부 기본 이벤트의 태그명이 안 나온다](2026-08-16-share-preview-deleted-tag-name-missing.md) — Event / fixed / 태그명 안나옴, 삭제된 태그, 드롭다운 빈 항목, tagName nil, stub이 미스를 못 만듦
