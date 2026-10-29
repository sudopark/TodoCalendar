# DP-2.1 — 첫 서브도메인 모듈 추출

Domain 에서 맨 아래 두 층을 처음으로 별도 모듈로 떼어 냈다. 공유 저장소·링크·기능 플래그·RRule 파서·기기 계약은 `KernelUtils` 로 갔다. Calendar 는 계약(`CalendarDomainInterface`)·구현(`CalendarDomain`)·리포지토리 포트(`CalendarRepositoryInterface`)로 갈렸다. 소비처 매니페스트와 import 는 하나도 안 고쳤다. `Domain` 과 `TestDoubles` 가 새 모듈을 `@_exported import` 로 다시 내보내 기존 `import Domain`·`import TestDoubles` 가 그대로 산다.

## 추출 틀

단계 3 의 나머지 추출이 따를 모양이다.

- 모듈 구성 — 스텁이 있는 서브도메인은 `frameworkWithInterfaceAndTesting` 으로 Interface·구현·Testing·Tests 넷을 세운다. 스텁이 없는 Kernel 은 `frameworkWithTest` 하나로 충분하다.
- usecase 파일 분할 — 프로토콜은 Interface 에, Imple 과 Imple 만 쓰는 타입(`LocaleProvider`)은 구현에 둔다.
- 리포지토리 포트 — `Repository/<X>Repository` 프로젝트의 Interface 에 둔다. 구현 타겟은 빈 `Sources` 로 세우고 `withTest: false` 로 테스트 스킴을 뺀다. 구현은 데이터 층 DP 가 채운다.
- 우산 — `Domain/Sources/Domain+Exports.swift`·`Supports/TestDoubles/Sources/TestDoubles+Exports.swift` 한 파일씩이다. Repository 쪽 선례(`Repository+Exports.swift`)와 이름을 맞췄다.
- 스텁 — Calendar 스텁은 `TestDoubles` 가 아니라 `CalendarDomainTesting`·`CalendarRepositoryTesting` 에 산다.

## 수치

- 측정 스크립트(`docs/blog/1150/scripts/target_graph.py`)가 이제 떼어 낸 모듈 디렉터리도 걷는다. 이동 뒤에도 `없음 — DAG` 이고 층 순서가 이동 전과 같다. 달라진 건 0층의 `DeviceInterface` 가 `Kernel_Utils` 에 합쳐진 것 하나다. Calendar→Kernel 간선은 이동 전후 모두 4개다.
- 새 테스트 스킴 둘 — `KernelUtils`(38건)·`CalendarDomain`(41건). Domain 스킴은 그만큼 줄었다. 전체 스킴 목록은 DP-2.2 위에서 22개였고 24개가 됐다.
- 재실행 스킴 수는 줄지 않았다. `CalendarDomain` 구현 파일 하나를 바꿔도 `derive-test-schemes.py --changed` 가 24개를 다 낸다. 모든 테스트 타겟이 `TestDoubles` 를 암묵 의존하고, `TestDoubles` 가 `Domain` 을, `Domain` 이 새 모듈을 의존해서다. 우산이 남아 있는 한 이 수는 안 줄어든다. 캠페인이 우산을 걷는 단계(4)에서 줄어야 할 값이다.

## 틀린 가설

우산 파일 하나의 `@_exported import` 가 Domain 모듈의 다른 파일에는 안 닿을 거라고 봤다. 그래서 `SharedDataStore` 를 쓰는 Domain 소스마다 `import KernelUtils` 를 더하게 될 거라고 예상했다. 실제로는 직접 import 를 하나도 안 더했는데 Domain 이 빌드됐다.

## 놀란 지점

거꾸로 새 모듈의 테스트에서는 재노출이 안 닿았다. `CalendarDomainTests` 는 `import TestDoubles` 를 하고 `TestDoubles` 는 `import Domain` 을 한다. 그래도 `SharedDataStore` 를 못 찾았다. `TestDoubles` 의 `import Domain` 은 평범한 import 라서 그걸 import 한 쪽까지 내보내지 않는다. 새 모듈 테스트는 자기가 쓰는 모듈(`KernelUtils`·`CalendarDomainInterface`·`CalendarRepositoryInterface`)을 직접 import 한다.

Domain 에 남은 테스트 둘(`EventRepeatTimeEnumeratorTests`·`RRuleEventRepeatingMappingTests`)은 `TimeInterval.days(_:)` 를 쓴다. 이 internal 헬퍼가 `CalendarDomainInterface` 로 넘어가면서 `@testable import Domain` 만으로는 안 보이게 됐다. 헬퍼를 public 으로 열지 않고 두 파일에 `@testable import CalendarDomainInterface` 를 더했다.

## 도구가 못 잡은 것

- `tuist inspect dependencies` 는 새 테스트 타겟의 암묵 의존을 짚는다(`CalendarDomainTests` → `KernelUtils`·`CalendarRepositoryInterface`, `DomainTests` → `CalendarDomainInterface`). 테스트 타겟 헬퍼가 테스트 대상 타겟만 링크하기 때문이다. 기존 `DomainTests` → `Extensions` 와 같은 갈래다. 코드 쪽 미선언 import 는 서드파티(Prelude·Optics)뿐이고, 이건 `Common3rdParty` 우산을 쓰는 레포 전체가 같다.
- 빈 소스 디렉터리는 git 이 안 담는다. 디렉터리가 없으면 `tuist generate` 가 glob 에서 실패한다. 빈 `Repository/CalendarRepository/Sources/` 에는 DP-2.2 선례대로 `.gitkeep` 을 뒀다.

## 되돌린 결정

없음.
