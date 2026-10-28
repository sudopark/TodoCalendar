# DP-1.2 — 스킴 배선을 매니페스트에서 도출하기

## 문제: 모듈 목록이 네 곳에 손으로 박혀 있었다

모듈 하나를 더하면 네 곳을 같이 고쳐야 했다.

- `Workspace.swift` 의 프로젝트 26개 나열
- `pr_test.yml` detect-changes 의 전체 스킴 문자열과 경로별 grep 매핑
- `pr_test.yml` test job 의 스킴별 step 17개
- `scripts/run-all-tests.sh` 의 `ALL_SCHEMES` 배열

#1150 은 Domain·Repository·Scenes 를 서브도메인 모듈 수십 개로 쪼갠다. 두 세션이 나란히 모듈을 만들면 이 네 곳이 매번 충돌 지점이 된다. 그래서 모듈을 늘리기 전에 목록부터 없앴다.

## 손 표는 이미 그래프와 어긋나 있었다

경로별 grep 매핑은 사람이 의존 관계를 외워 쓴 표였다. 매니페스트에서 계산한 결과와 대 보니 이런 자리가 나왔다.

- `Presentations/AIAgentScene`·`BillingScenes` 를 고쳐도 앱 스킴이 안 돌았다. 앱은 둘 다 의존한다.
- 위젯 확장 소스를 고쳐도 앱 스킴이 안 돌았다. 앱이 위젯을 embed 한다.
- `Scenes`·`UnitTestHelpKit` 은 테스트 타겟이 있는데 CI 가 한 번도 안 돌렸다. 목록에 없었기 때문이다.
- `TestDoubles` 를 고치면 Domain 테스트를 건너뛰었다. 주석은 "Domain 테스트는 TestDoubles 를 사용하지 않음" 이라고 했지만, 테스트 타겟 템플릿이 TestDoubles 를 모든 테스트 타겟에 붙인다.

반대로 손 표가 더 넓던 자리도 있었다. 모듈의 `Tests/` 만 고쳐도 그 모듈에 의존하는 스킴까지 다 돌렸다. 테스트 소스는 자기 테스트 타겟에만 들어가므로 자기 스킴 하나면 된다.

## 방법: tuist 없이 Project.swift 를 읽는다

detect-changes job 은 ubuntu 러너에서 tuist 없이 돈다. 그래서 그래프를 tuist 로 뽑지 않고 `Project.swift` 를 직접 파싱했다 (`scripts/derive-test-schemes.py`).

- 프로젝트 목록은 `Workspace.swift` 의 glob 을 스크립트가 그대로 읽어 찾는다. 워크스페이스와 스크립트가 따로 놀 짝이 없다.
- 프로젝트 간 의존은 전부 `.project(target:path: .relativeToRoot(...))` 한 형태라 괄호 짝을 맞춰 읽으면 된다. `.external`·`.sdk`·`.xctest` 는 모듈 간선이 아니라 건너뛴다. 그 밖의 형태가 나오면 경로를 찍고 실패한다. 모르는 간선을 조용히 넘기면 CI 가 돌아야 할 스킴을 건너뛰기 때문이다.
- 노드는 프로젝트 단위로 두되 앱 프로젝트만 타겟 단위(앱·Widget·Share·IntentExtensions)로 갈랐다. 확장마다 의존이 달라서다.
- 영향 규칙은 한 줄이다. 스킴 S 의 의존 집합은 S 모듈의 폐포에 테스트 타겟이 붙이는 의존의 폐포를 더한 것이고, 변경된 노드가 그 안에 있으면 S 를 돌린다.

## 의존 선언 밖의 관계는 표와 짝 테스트로 묶었다

`Project.swift` 만 읽어서는 안 보이는 관계가 둘 있었다.

- 테스트 타겟 템플릿이 암묵으로 붙이는 `UnitTestHelpKit`·`TestDoubles`·`Common3rdParty`
- 확장 타겟이 모듈 의존 없이 앱 프로젝트 경로(`AppExtensions/Base/**`·`Sources/LiveActivity/**` 등)를 직접 컴파일하는 것

둘 다 스크립트 안에 표로 두었다. 표는 낡으면 조용히 틀린다. 그래서 짝 테스트가 `Project+Templates.swift` 를 읽어 표와 대조하고, detect-changes 가 매핑 전에 그 테스트를 먼저 돈다. 템플릿을 고치고 표를 안 고치면 CI 가 그 자리에서 멈춘다. 템플릿의 `public static func` 헬퍼가 분류 표에 다 있는지도 같은 방식으로 본다.

## 확인

- glob 워크스페이스가 모은 프로젝트 집합은 전과 같다 (자체 26개, 의존 패키지 포함 61개 항목).
- 시험 모듈 `Domain/ZZProbeDomain` 을 새 헬퍼로 넣자 손 등록 없이 워크스페이스·전체 스킴 목록·변경 매핑에 잡혔고, 그 스킴의 테스트가 통과했다. 지운 뒤 `tuist inspect dependencies`·`tuist graph` 는 develop 과 같았다 (타겟 249개).
- 새로 CI 에 들어간 `Scenes`·`UnitTestHelpKit` 은 로컬 첫 실행에서 통과했다.
- 전체 실행 대상은 16개에서 19개가 됐다. `Scenes`·`UnitTestHelpKit` 이 새로 들어왔고, 전에는 자기 경로가 바뀔 때만 돌던 `Extensions` 도 전체 실행에 들어왔다.

## 기준선

| 항목 | 값 |
|---|---|
| CI test job, 전 16 스킴 (DerivedData 리셋) | 12m47s — 최근 런 셋 12m09s·12m47s·13m25s 의 중앙값 |
| 로컬 `tuist generate --no-open` (develop) | 8.1s — 세 번 잰 중앙값 |

CI 기준선은 이 DP 전의 16 스킴 기준이다. 이후 DP 는 이 값과 비교하되 스킴 수 차이를 같이 본다. 모듈이 늘어 generate 가 느려지는지, 변경 범위가 좁아져 CI 가 덜 도는지가 볼 거리다.
