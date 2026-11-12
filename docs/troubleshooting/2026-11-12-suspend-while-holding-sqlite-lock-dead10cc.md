---
issue: "#1390"
subdomain: Infra
symptoms: [0xdead10cc, RUNNINGBOARD, EXC_CRASH SIGKILL, 백그라운드 진입 직후 종료, 다음 진입 때 콜드 스타트, SQLite 락, WAL fsync, 포그라운드 복귀 sync, Organizer 에만 보이는 크래시]
resolution: deferred
---

# 포그라운드 복귀 refresh 가 SQLite 에 쓰는 동안 suspend 되면 0xdead10cc 로 죽는다

- **증상**: Xcode Organizer 크래시 포인트 `CjYEnaLgy_vNU7Np1uygIa`. 3.1.3 (1) TestFlight 에서 `RUNNINGBOARD 0xdead10cc` SIGKILL 1건. Crashlytics 에는 안 잡힌다 — SIGKILL 이라 Organizer 로만 보인다. 종료 순간 구글 캘린더 DB 의 DELETE 가 WAL 커밋 `fsync` 중이었고(`GoogleCalendarLocalStorageImple.removeEvents`), 메인 DB 에서는 sync 타임스탬프 조회와 플랜 저장(`AIAgentUsageUsecaseImple.loadUsage` → `BillingUserPlanLocalRepositoryImple.updatePlan`)이 줄 서 있었다. 메인 스레드는 화면 밝기 변화 콜백에 있었다.
- **근본 원인**: `willEnterForegroundNotification` 이 `eventSyncUsecase.sync()`·`refreshEvents`(구글 refresh)·`loadUsage()` 를 한꺼번에 시작하고, 이 흐름들은 백그라운드 실행 시간을 요청하지 않는다. 보호가 있는 자리는 `BackgroundEventSyncUsecaseImple.handleBackgroundSync` 의 BGAppRefreshTask 경로뿐이다. `ApplicationPrepareUsecaseImple.prepareEnterBackground` 도 `wal_checkpoint` 만 돌리고 진행 중 작업을 기다리지 않는다. 복귀 직후 화면을 잠그면 suspend 가 WAL 커밋 중간에 들어오고, App Group 안 SQLite 락을 쥔 채 suspend 된 프로세스를 OS 가 죽인다.
- **해결**: deferred — DB 접근 경계에서 실행 중인 `SQLiteService.run` 작업이 끝날 때까지 백그라운드 실행 시간을 요청한다 (`ProcessInfo.performExpiringActivity` 또는 앱 레이어가 주입한 `beginBackgroundTask`). 복귀 refresh 세 갈래·`wal_checkpoint`·플랜 저장이 한 자리에서 덮인다. 재현은 실기기 suspend 타이밍이라 하지 않았고, 크래시 로그 스레드 상태와 코드 경로로 확정했다. 후속 이슈 #1390.
- **기각 방향**: `didEnterBackground` 에서 `cancelSync` — 진행 중인 `fsync` 커밋은 취소로 멈추지 않고, 받아 둔 동기화 결과도 버린다. / 복귀 refresh 세 출발점마다 `beginBackgroundTask` — 쓰기 자리마다 심어야 유지되는 증상 패치다.
