---
issue: "#990"
subdomain: Infra
symptoms: [Repository 스킴 랜덤 실패, illegal multi-threaded access to database connection, vnode unlinked while in use, Restarting after unexpected exit, BaseLocalTests, 플레이키]
resolution: fixed
---

# 로컬 DB 테스트가 런마다 다른 지점에서 크래시

- **증상**: `Repository` 스킴을 통째로 돌리면 매번 다른 테스트가 깨진다. 같은 커밋 3회 실행에서 1회 FAILED. 로그에 sqlite API 위반이 런당 132~142건 찍히고 `Restarting after unexpected exit` 로 프로세스가 재시작된다.

  ```
  BUG IN CLIENT OF libsqlite3.dylib: illegal multi-threaded access to database connection
  BUG IN CLIENT OF libsqlite3.dylib: database integrity compromised by API violation:
    vnode unlinked while in use: .../Caches/temps.db
  ```

- **근본 원인**: `BaseLocalTests` 가 두 조건을 동시에 만족시켰다.
  1. DB 파일명이 **클래스당 고정**(`temps.db`·`todos.db` 등)이라 클래스 안 모든 테스트가 같은 vnode 를 쓴다.
  2. `tearDownWithError` 가 `sqliteService = nil` 로 참조만 끊고 곧바로 파일을 지운다. 커넥션은 `SQLiteDataBase.deinit` 이 임의 스레드에서 닫는데, 그 시점에 이전 테스트의 쿼리가 아직 serial access queue 에서 돌고 있으면 `sqlite3_close` 와 겹친다.

- **해결**: `fileName` 에 테스트마다 다른 UUID 를 붙여 vnode 공유를 없애고, `tearDown() async` 에서 `async.close()` 로 pending 작업을 배수한 뒤 파일을 지운다. `AICommandRepositoryImpleTests` 는 `fileName` 지정이 `super.setUpWithError()` 뒤에 있어 반영되지 않았던 것도 함께 고쳤다.

  실측: 수정 후 5회 전부 통과, sqlite 위반 23~26건, 런 시간 34s → 17s.

- **기각 방향**: open 을 완료 콜백 API 로 바꿔 쿼리와 같은 serial access queue 에서 연다 — `illegal multi-threaded access` 진단이 **크래시 난 회차에만** 뜨고 통과 회차엔 0건이었다. open 은 매 테스트 항상 메인에서 했으므로 그게 원인이면 상시 떴어야 한다. setUp 의 open 과 테스트 본문의 쿼리는 시간상 순차라 동시 접근이 아니고, 그 진단은 동시 접근에서 뜬다. 실제 원인은 tearDown 의 close 가 다른 스레드의 쿼리와 겹친 것이라 close 조항이 흡수한다. 세마포어로 콜백을 동기화하면 콜백이 안 올 때 타임아웃 없이 매다는 경로만 새로 생긴다.

- **재발 시 판별**: `Executed N tests, with 0 failures` 인데 `exit 65` 이거나 실행 개수가 런마다 다르면 크래시다. 로그에서 `vnode unlinked while in use` 뒤의 파일명을 보면 어느 테스트 클래스인지 바로 나온다.
