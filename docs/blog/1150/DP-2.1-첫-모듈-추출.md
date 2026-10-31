# DP-2.1 — 서브도메인 수직 분할을 한 번에

`Domain`·`Repository`·`Scenes` 세 목구멍을 서브도메인 열한 개와 Scene 계약 여덟 개로 갈랐다. 처음엔 Kernel·Calendar 둘만 떼고 나머지는 우산(`@_exported import`)으로 버티며 DP 열한 개에 나눠 옮길 계획이었다. 재작업 중 순환이 드러났고, 유저가 "DP 나누지 말고 한 번에" 로 방향을 바꿨다. 그래서 우산을 거치지 않고 최종 구조로 바로 갔다.

## 최종 모양

- 서브도메인마다 `Domain/<X>Domain/` 프로젝트 하나에 `<X>DomainInterface`(모델·usecase 프로토콜·리포지토리 포트)·`<X>Domain`(usecase 구현 `Sources/Usecases` + 리포지토리 구현·테이블·엔드포인트 `Sources/Repositories`)·`<X>DomainTesting`(스텁)·`<X>DomainTests` 넷이 선다.
- 0층은 `KernelUtils`·`PlaceServiceInterface` 단독 모듈이다. 인프라 셋(`StorageInfra`·`DBInfra`·`RemoteInfra`)은 그대로다.
- `Scenes` 는 `SceneInfra`(Scene 기반 타입·팩토리 프로토콜) 와 `<X>SceneInterface` 여덟 개로 갈렸다. `TestDoubles` 는 `BaseSpyRouter` 하나만 남았다.
- 소비처는 실제로 쓰는 Interface 만 선언한다. 구현 타겟을 아는 건 조립 루트(앱)뿐이다.

## 수치

- 측정 스크립트(`scripts/target_graph.py`)가 이제 디렉터리로 서브도메인을 정한다. 리포지토리 구현이 구현하는 포트의 서브도메인 디렉터리에 살아서 따로 분류할 게 없다. 결과는 `없음 — DAG` 이고 층은 0 `Kernel_Utils·MigrationDomain·PlaceServiceInterface` → 1 `Billing·Calendar` → 2 `Event` → 3 `Notification` → 4 `Account·Setting` → 5 `Ad·ExternalCalendar·Support` → 6 `AI` → 7 마이그레이션 구현이다.
- 재실행 스킴 수 — `CalendarDomain` 구현 파일 하나를 바꾸면 `derive-test-schemes.py --changed` 가 5개를 낸다(`CalendarDomain`·`CalendarScenes`·`MigrationDomain`·앱·위젯). 분할 전에는 모든 테스트 타겟이 `TestDoubles` → `Domain` 으로 이어져 그때 스킴 24개가 전부 돌았다. 지금 스킴은 32개다. Interface 를 바꾸면 그 Interface 를 쓰는 쪽이 다 돈다.

## 틀린 가설

리포지토리 구현은 인프라 셋의 Interface 만 본다고 봤다. 실제로는 `RemoteInfraInterface` 가 `Domain` 을 통째로 의존하고 있었다. 쓰는 건 `ServerErrorModel`·`Auth`·`OAuth2Credential` 셋뿐이었다. `CalendarDomain` 이 원격 API 를 쓰는 순간 `CalendarDomain → RemoteInfraInterface → Domain → CalendarDomain` 이 됐다. 세 타입을 제자리(`KernelUtils`·Account 계약·`RemoteInfra` 구현)로 옮겨 끊었다.

## 놀란 지점

스킴 도출 스크립트가 프로젝트 단위로 영향을 셌다. Interface·구현·Testing 을 한 프로젝트에 두니 구현 파일만 바꿔도 그 프로젝트 Interface 를 쓰는 쪽이 전부 다시 돌았다. 분할의 효과가 도구에서 사라지는 자리였다. `frameworkWithInterfaceAndTesting` 프로젝트는 타겟 넷을 따로 노드로 세우고 경로 디렉터리로 바뀐 타겟을 고르게 고쳤다.

## 도구가 못 잡은 것

- 다른 모듈의 extension 멤버(`TimeInterval.days`, `CalendarDay.link` 등)는 타입 참조가 없어서 import 추정이 못 짚는다. 파일에서 `.멤버` 를 찾아 그 extension 을 가진 Interface 를 붙이는 보조 규칙을 썼다.
- `Domain.Auth` 처럼 모듈 이름으로 한정한 타입은 우산이 사라지자 컴파일 에러로만 드러났다.

## 되돌린 결정

우산(`@_exported import`)으로 단계마다 소비처 무수정을 지키는 방식을 버렸다. 단계를 나누지 않으니 우산이 필요 없었다.

## 남은 예외

- 구현→구현 의존은 마이그레이션 구현 하나만 허용하기로 했지만 셋이 더 남았다. `NotificationDomain`·`ExternalCalendarDomain` 구현이 `EventDomain` 구현의 이벤트 시간 테이블·알림 옵션 매퍼를, `AIDomain` 구현이 `BillingDomain` 구현의 플랜 매퍼를 쓴다.
- `SceneInfra` 의 팩토리 프로토콜이 서브도메인 Interface 열한 개와 `KernelUtils` 를 다 안다. 그래서 어느 Interface 를 바꿔도 모든 Scene 테스트가 돈다.
