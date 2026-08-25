---
issue: "#1003"
subdomain: Infra
symptoms: [CI 반복 실패, Exceeded timeout of, 매번 다른 테스트가 깨짐, 로컬은 통과 CI만 실패, PublisherWaitable, 플레이키]
resolution: workaround
---

# CI 가 브랜치와 무관하게 매번 다른 테스트에서 타임아웃으로 깨진다

- **증상**: PR CI 가 반복 실패하는데 깨지는 테스트가 런마다 다르다. 실패 메시지는 전부 `Exceeded timeout of N seconds` 형태로, 로직 단언이 틀린 게 아니라 시간이 모자라 깨진다. 같은 커밋이 로컬에서는 14/14 통과한다. 특정 브랜치 문제가 아니라 여러 PR(#981·#982·#881·#998)에서 동일하게 났다.

- **근본 원인**: 테스트 스위트 전체가 벽시계 고정 타임아웃에 결합돼 있다. wait 호출 1113건이 전부 "정해진 시간 안에 방출이 오는가"로 판정한다. CI 는 self-hosted 러너(`Maggie-m1`)에서 매번 `rm -rf ./DerivedData` 후 클린 빌드로 도는데(`.github/workflows/pr_test.yml` `Reset DerivedData`), 로컬 증분 실행보다 느리고 부하 변동이 크다. 부하가 튀는 순간 실행 중이던 테스트가 상한을 넘고, 어느 테스트가 걸릴지는 매번 달라 다른 게 깨진다.

  판별 근거: 같은 커밋의 두 CI run 이 서로 다른 스킴에서 실패했다 — run 32794396178 은 `SettingItemListViewModelImpleTests.test_selectAdPrivacyOptions_routesToAdPrivacyOptionsForm`(타임아웃 미지정 = 기본 0.5초), run 32806771882 는 `TodoLocalRepositoryImpleTests.testRepository_whenSkipRepeatingTodo_consumeTurn`(`stubSaveTodo` 의 명시 `timeout: 1`). 코드 결함이면 같은 지점에서 깨져야 한다.

  Repository 쪽에 함께 찍힌 `prepare("bad parameter or other API misuse")` 는 별개 원인이 아니라 후속 증상이다. `stubSaveTodo` 가 저장 완료를 기다리다 상한을 넘으면 저장이 안 끝난 채 테스트 본문이 진행돼 DB 상태가 어긋난다.

- **해결**: 국소 방편으로 `PublisherWaitable` 기본 타임아웃을 올렸다 — XCTest `0.5s → 2.0s`, Swift Testing `expectConfirm` `1s → 3s`. CI 에서 실제로 깨졌던 `stubSaveTodo`·`stubSaveSchedule` 의 명시 `timeout: 1` 은 제거해 기본값을 타게 했다.

  positive 대기는 값이 오면 즉시 반환하므로 상한만 올라가고 실행 시간은 늘지 않는다 (SettingScene 5.38s → 4.97s 실측).

  **한계·재발 조건**: 근본은 그대로다. 부하가 더 튀면 다시 깨진다. 짧은 명시 타임아웃(`timeout: 0.1` 82건 등)은 손대지 않아 그쪽이 먼저 걸릴 수 있다. 진짜 무한대기 회귀도 상한이 올라간 만큼 늦게 잡힌다.

  **후속**: #1003 — 벽시계 대기를 조건 폴링(`AsyncEffectWaitable.waitEffect`, #990 도입)으로 점진 전환. 현재 채택 파일이 3개뿐이다.

- **기각 방향**:
  - CI `-retry-tests-on-failure` 로 실패분만 재실행 — 플레이키를 숨기는 쪽이라 진짜 간헐 버그도 같이 묻힌다. 원인이 환경 의존임을 이미 확정한 상태에서 신호를 지우는 선택은 이득이 없다.
  - 짧은 명시 타임아웃(`0.1` 82건)까지 일괄 상향 — 그중 상당수가 "방출이 없어야 한다"를 검증하는 negative 대기다. 그건 상한까지 기다렸다가 부재를 확인하는 구조라 올리면 테스트 시간만 그만큼 늘고 판정은 그대로다. positive/negative 구분이 선행돼야 해서 #1003 으로 미뤘다.

- **재발 시 판별**: 실패 메시지가 `Exceeded timeout of` 이고 로컬에서 같은 커밋이 통과하면 이 건이다. 깨진 테스트가 런마다 바뀌는지 확인하면 확정된다 — 고정이면 진짜 회귀다.
