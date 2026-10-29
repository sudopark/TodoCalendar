# DP-2.2 — 저장소 인프라를 세 모듈로 떼기

## 왜 먼저 뗐나

`Repository` 를 서브도메인별 저장소 모듈로 나누려면, 새 모듈이 기댈 바닥이 먼저 있어야 한다. 그 바닥은 UserDefaults·Keychain 저장소, 외부 캘린더 DB 연결 풀, 원격 API·인증이다. 이것들이 `Repository` 안에 있으면 `CalendarRepository` 같은 새 모듈은 결국 `Repository` 전체를 의존하게 된다. 그래서 인프라부터 `StorageInfra`·`DBInfra`·`RemoteInfra` 로 떼었다.

## 가른 기준: Interface · Sources · Testing

모듈마다 세 타겟을 둔다.

- **Interface** — 다른 모듈이 타입으로 참조하는 프로토콜과 값 타입이다. `RemoteAPI`·`Endpoint`·`APICredential`·`AuthStore`·`FirebaseAuthService` 가 여기 간다.
- **Sources** — 그 프로토콜의 구현이다. 조립 지점(앱)만 이 타겟을 안다.
- **Testing** — 여러 모듈의 테스트가 같이 쓰는 더블이다. `StubRemoteAPI`·`FakeEnvironmentStorage` 가 여기 간다. 한 모듈 테스트만 쓰는 더블은 그 모듈 `Tests/` 에 남긴다.

새 저장소 모듈은 Interface 만 의존하면 된다. 구현이 바뀌어도 그 모듈은 다시 빌드할 일이 줄어든다.

## 섞인 파일은 이동과 자르기로 갈랐다

파일 대부분이 구현이면 `git mv` 로 Sources 에 옮기고, 프로토콜·값 타입만 잘라 Interface 새 파일에 두었다. 이렇게 하면 이력이 큰 쪽 파일을 따라간다.

- `RemoteAPI.swift` 는 Sources 로 옮기고, 메서드 enum·프로토콜·기본 구현을 Interface 로 잘라냈다.
- `Authenticators.swift` 는 대부분 프로토콜이라 반대로 Interface 로 옮기고, `AuthenticationInterceptorProxy` 만 Sources 로 잘라냈다.
- `AuthRepositoryImple.swift` 앞부분에 있던 Firebase 인증 서비스는 프로토콜과 구현으로 갈라 RemoteInfra 로 보냈다. 남은 `AuthRepositoryImple` 은 더 이상 `FirebaseAuth` 를 import 하지 않는다.

코드는 import 줄·헤더·접근 수준·선언 가르기만 바꿨다. 이동과 동작 변경을 섞으면 회귀가 났을 때 원인을 못 가른다. 예외는 하나였다. 연결 풀 테스트가 `Repository` 에 남는 테이블로 연결을 확인하고 있어서, 테스트 파일 안에 확인용 테이블을 하나 두었다.

## 엔드포인트는 통째로 두었다

`Endpoint.swift` 는 엔드포인트 enum 17개와 그 경로를 푸는 `RemoteEnvironment.path(_:)` switch 를 한 파일에 담고 있다. 서브도메인별로 엔드포인트를 나누려면 이 switch 를 먼저 걷어야 하고, 그건 DP-2.5 가 맡는다. 지금 가르면 같은 코드를 두 번 옮기게 돼서, 이번엔 파일을 통째로 Interface 에 두고 internal enum 13개를 public 으로만 열었다.

## 소비처는 한 줄도 안 고쳤다

`Repository` 가 여섯 모듈(Interface 셋·구현 셋)을 `@_exported import` 로 다시 내보낸다. 앱·위젯·공유 확장은 계속 `import Repository` 하나로 빌드되고 테스트가 통과했다. 소비처 매니페스트와 import 를 고치는 일은 단계 4 로 미뤘다. 두 세션이 같은 소비처를 동시에 고치는 충돌을 피하려는 것이다.

## 헬퍼가 넓어진 자리

- 소스 없는 `DBInfraTesting` 은 디렉터리가 아예 없으면 `tuist generate` 가 glob 오류로 실패한다. 빈 디렉터리에 `.gitkeep` 을 두면 빌드·링크까지 된다.
- `frameworkWithInterfaceAndTesting` 의 테스트 타겟이 자기 Interface 도 의존하게 했다. 테스트가 그 모듈의 프로토콜을 import 하는데 의존 선언이 없어 `tuist inspect` 에 걸렸기 때문이다.
- `SpyKeyChainStorage` 가 구현 쪽 `AuthMapper` 로 Keychain 값을 만들어서, `RemoteInfraTesting` 은 `RemoteInfra` 를 의존한다.

## 확인

| 항목 | develop | 이 DP |
|---|---|---|
| `tuist graph` 노드·간선 | 289 · 746 | 301 · 796 (인프라 타겟 12개 추가) |
| 순환 | 0 | 0 |
| Repository 계열 테스트 (Swift Testing · XCTest) | 413 · 264 | 413 · 264 (Repository 382·257 + 인프라 31·7) |
| 로컬 `tuist generate --no-open` | 8.1s (DP-1.2 기준선) | 6.0s |

`tuist inspect dependencies --only implicit` 를 develop 과 대조했을 때 새로 생긴 미선언 import 는 두 갈래뿐이다. 하나는 `Repository` 가 Common3rdParty 로 받던 서드파티(Alamofire·FirebaseAuth·KeychainSwift)가 그 코드를 따라 인프라 모듈로 옮겨간 것이다. 다른 하나는 인프라 테스트 타겟이 Domain·Extensions·StorageInfraInterface 를 선언 없이 import 하는 것이다. develop 의 `RepositoryTests` 도 Domain·Extensions 를 같은 방식으로 쓰고 있어서 기존 관례 안에 있다.
