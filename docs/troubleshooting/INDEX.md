# Troubleshooting Index

버그·논리 모순의 규명 결과와 결정된 해결책 아카이브. 조회·기록 절차와 레코드 템플릿은 `.claude/skills/troubleshoot/SKILL.md`.

한 줄 포맷: `- [YYYY-MM-DD 제목](파일.md) — 서브도메인 / resolution(fixed|workaround|deferred|non-issue) / 증상 키워드`

<!-- 레코드는 아래에 최신순으로 추가 -->

- [2026-08-19 애플 캘린더 반복 일정의 종료일이 앱 상세에서 하루 뒤로 보인다](2026-08-19-apple-repeat-until-off-by-one-day.md) — ExternalCalendar / fixed / 애플 반복 종료일 하루 뒤, UNTIL 하루 밀림, EKRecurrenceEnd endDate, 반복 종료 타임존

- [2026-08-16 구글 이벤트의 시간 표현을 바꾸면 `Invalid start time` 400 이 뜬다](2026-08-16-google-event-time-type-switch-invalid-start-time.md) — ExternalCalendar / fixed / Invalid start time, 구글 이벤트 종일 전환 400, date dateTime 공존, patch 병합

- [2026-08-09 종료조건이 n회인 반복 할일이 n회를 훌쩍 넘겨서까지 반복된다](2026-08-09-repeating-todo-count-end-not-working.md) — Event / fixed / 반복 todo count 종료 안됨, 종료조건 n회 초과 반복, repeatingTurn 유실, 업로드 후 turn 리셋

- [2026-08-09 중지를 눌러도 서버에 cancel이 안 나가고, 중지한 job의 결과가 뒤늦게 뜬다](2026-08-09-ai-job-stop-not-reaching-server.md) — AIAgent / fixed / 중지 안됨, 중지 후 완료 푸시, 복귀 시 진행중 안보임, 결과 시트 뒤늦게 노출, Combine throttle 지연

- [2026-08-08 run-all-tests.sh가 컴파일 실패를 PASSED로 보고한다](2026-08-08-run-all-tests-reports-compile-failure-as-passed.md) — Infra / fixed / PASSED 오보, 컴파일 에러인데 통과, TEST FAILED 미감지, Executed 0 tests

- [2026-08-07 비반복 이벤트를 롱탭했는데 컨텍스트 메뉴에 "이번만 삭제"가 뜬다](2026-08-07-day-event-list-context-menu-shows-wrong-remove-action.md) — Event / fixed / 이번만 삭제 오노출, 메뉴 깜빡임, 탭 무반응, 셀 목록 재방출

- [2026-08-07 키보드 입력 시트에서 커맨드를 전송하면 present 충돌로 크래시](2026-08-07-ai-command-sheet-present-while-keyboard-sheet-up.md) — AIAgent / fixed / already presenting, 바텀시트 크래시, 키보드 입력 전송
- [2026-08-06 Share Extension으로 만든 AI job의 결과 푸시가 안 온다](2026-08-06-share-extension-ai-job-no-push.md) — AIAgent / non-issue / 푸시 안옴, device_id, DailyLimitExceeded, share extension
- [2026-08-15 공유 미리보기에 조회 범위와 안 겹치는 이벤트가 섞여 나온다](2026-08-15-share-preview-shows-events-outside-range.md) — Event / fixed / 범위 밖 이벤트 노출·반복 일정 turn·clamped 재판정 누락

- [2026-08-16 공유 미리보기에서 일부 기본 이벤트의 태그명이 안 나온다](2026-08-16-share-preview-deleted-tag-name-missing.md) — Event / fixed / 태그명 안나옴, 삭제된 태그, 드롭다운 빈 항목, tagName nil, stub이 미스를 못 만듦
- [2026-08-22 DayEventList 라이브액티비티 해제 표시 테스트 간헐 타임아웃](2026-08-22-dayeventlist-live-activity-clear-mark-flaky.md) — Event / deferred / whenLiveActivityUnregistered_cellViewModelsClearMark·Exceeded timeout of 2 seconds·간헐 실패
- [2026-08-22 구글 이벤트 개별 색상이 라이브액티비티에서 무시됨](2026-08-22-google-event-custom-color-ignored-in-live-activity.md) — ExternalCalendar / fixed / 구글 이벤트 색상·커스텀 색상 무시·라이브액티비티 색·colorId
- [2026-08-22 캘린더 하단 배너를 붙이자 플랜 구독 합성에서 격리 어서션 크래시](2026-08-22-ad-banner-plan-binding-main-actor-crash.md) — Billing / fixed / 배너 광고 크래시·_swift_task_checkIsolatedSwift·dispatch_assert_queue_fail·MainActor 격리 위반
- [2026-08-24 로컬 DB 테스트가 런마다 다른 지점에서 크래시](2026-08-24-local-db-tests-random-crash.md) — Infra / fixed / illegal multi-threaded access·vnode unlinked while in use·Repository 스킴 랜덤 실패
- [2026-08-24 `.timeout` 이 concurrent 큐에서 동기 방출값을 흘린다](2026-08-24-combine-timeout-drops-value-on-concurrent-queue.md) — Event / fixed / 라이브액티비티 placeName·memo nil·Publishers.Timeout·DispatchQueue.global
- [2026-08-24 백그라운드 Task 에서 구독을 담다 Set 저장소가 깨진다](2026-08-24-cancelbag-data-race-crash.md) — Infra / fixed / unrecognized selector 0x8000000000000000·member:·CalendarScenes 랜덤 크래시
- [2026-08-24 Paywall screenState 테스트가 방출 개수로 흔들린다](2026-08-24-paywall-screenstate-emission-count-flaky.md) — Billing / deferred / Confirmation was confirmed·PaywallViewModelImpleTests·BillingScenes 간헐 실패
- [2026-08-25 CI 가 브랜치와 무관하게 매번 다른 테스트에서 타임아웃으로 깨진다](2026-08-25-ci-wallclock-timeout-flaky.md) — Infra / workaround / CI 반복 실패·Exceeded timeout of·매번 다른 테스트·로컬은 통과
- [2026-08-26 `Text(timerInterval:)` 을 좁은 행에 넣으면 크래시하거나 자릿수가 `--` 로 빠진다](2026-08-26-live-activity-timer-text-layout-traps.md) — Event / fixed / 라이브액티비티 잠금화면 크래시·LayoutSubview.place·GeometryReaderLayout·카운트다운 1:15:--·fixedSize
