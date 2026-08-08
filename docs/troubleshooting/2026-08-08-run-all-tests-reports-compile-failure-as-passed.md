---
issue: "#798"
subdomain: Infra
symptoms: [run-all-tests.sh PASSED 오보, 컴파일 에러인데 통과, TEST FAILED 미감지, Executed 0 tests]
resolution: fixed
---

# run-all-tests.sh가 컴파일 실패를 PASSED로 보고한다

- **증상**: 테스트 타겟 컴파일이 깨진 상태에서 `./scripts/run-all-tests.sh <scheme>`이 `-> PASSED`를 찍는다. 회귀 게이트가 새서 "전체 통과"를 신뢰할 수 없다.

- **근본 원인**: 판정문이 `EXIT_CODE -eq 0 || (세 grep 패턴이 전부 0)` 구조였다. 뒤쪽 절 때문에 exit code가 65여도 패턴에 안 걸리면 PASSED로 떨어진다. 그런데 세 패턴(`BUILD FAILED|xcodebuild: error:`, `with N failure`, `suites failed`) 중 어느 것도 컴파일 에러를 못 잡는다 — `xcodebuild test`는 `** TEST FAILED **`를 찍고 에러 줄은 `/path/File.swift:22:43: error:` 형태라 `xcodebuild: error:` 리터럴에 안 걸리며, 테스트가 실행조차 안 돼 실패 카운트 패턴도 안 나온다.

  `||` 뒤쪽 절은 `| xcpretty` 파이프로 exit code가 xcpretty 것으로 잡히던 시절의 우회 유물이다. 출력을 process substitution으로 돌려 xcodebuild exit code를 직접 잡게 바꾼 시점에 같이 제거됐어야 했다.

- **해결**: 판정을 exit code 단일 기준으로 정리했다.
  - `EXIT_CODE -ne 0` → 무조건 FAILED. grep 기반 보조 판정 3종 제거.
  - exit code 캡처는 `2>&1 | tee | xcpretty` + `PIPESTATUS[0]`으로 변경. process substitution은 bash가 완료를 기다리지 않아 `cat "$TMPFILE"`이 잘린 출력을 읽을 수 있었다 — 파이프라인은 전부 끝난 뒤 반환하므로 진단 grep도 온전한 출력을 본다.
  - 0개 실행 감지 추가: XCTest `Executed [1-9]* test` / Swift Testing `Test run with [1-9]* test` 둘 다 없으면 FAILED. `-only-testing`에 잘못된 이름을 넘겨 0개 실행되고도 `** TEST SUCCEEDED **` + exit 0이 나오는 오보를 막는다.

  검증: Extensions 테스트에 의도적 타입 에러를 넣고 수정 전 실행 → PASSED(RED 재현), 수정 후 → `FAILED (exit 65)`. 에러 되돌린 뒤 Extensions(XCTest 혼재)·AuthService(Swift Testing 전용) 둘 다 PASSED.

- **기각 방향**: `** TEST FAILED **` 패턴을 grep 목록에 추가 — 판정을 exit code로 일원화하면 패턴 유지보수 자체가 불필요해진다. 진단 출력용으로만 남겼다.
- **기각 방향**: Swift Testing 전용 스킴 때문에 `Executed 0 tests`를 단독 신호로 쓰기 — 그런 스킴(BillingScenes·TodoCalendarAppShare·AuthService)은 XCTest 쪽이 항상 `Executed 0 tests`를 찍어 false FAILED가 난다. 두 마커 부재를 AND 조건으로 묶어 해소.
