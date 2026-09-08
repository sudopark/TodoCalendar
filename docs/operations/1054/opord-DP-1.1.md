# 작전명령 — #1054 격리 판정축 분리와 e2e 타겟·스킴 신설

> 용어 — DP: 결정적 지점(작전명령 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

작전명령 — #1054 격리 판정축 분리와 e2e 타겟·스킴 신설       초안: 에이전트   재가: 유저   일자: 2026-09-08
상위: campaign.md #826 / LOE-1·LOE-3 / 1단계 / DP-1.1 / 선행 DP 없음

## ■ 확인보고

**임무 (내 말로)** — `isTestBuild` 하나가 지금 "외부 의존을 끊는다"와 "화면을 안 띄운다" 두 일을 겸하고 있는데, XCUITest 는 앱 프로세스에 `XCTestConfigurationFilePath` 를 안 심어서 둘 다 안 걸린다. 이 둘을 갈라 e2e 를 앞쪽에만 편입시키고, 그걸 실제로 돌려볼 e2e 타겟·독립 스킴을 세운다. 픽스처·스텁 서버는 안 만든다 — DP-1.2 소관이다.

**의도** — 목적은 DP-1.2 가 스텁 서버를 붙일 자리를 만드는 것. 최종상태는 넷이다: e2e 스킴으로 앱이 뜬다 / 프로덕션 변경이 계산 프로퍼티 2개 + 술어 교체 4곳으로 끝난다 / e2e 스킴이 `TodoCalendarApp` 스킴에 안 섞인다 / 기존 유닛 테스트가 전건 통과한다.

**자율로 정할 것** — 계산 프로퍼티 구현 형태, `makeE2ETarget` 내부 구성, 스모크 테스트 작성 방식, 우발계획 U-1~U-4 발동 시의 보정. 스킴이 자동 생성으로 안 갈리면 명시 정의로 전환하는 것(D-1)도 자율이다.

**묻는 것** — 없음. 판정축 모양과 짝규칙 예외 처리는 이미 결심받았고, 나머지는 정찰로 확정됐다.

## 1. 상황

### 가. 정찰 결과

- `AppEnvironment.isTestBuild` (`TodoCalendarApp/Sources/AppEnvironment.swift:16`) 는 `XCTestConfigurationFilePath` 환경변수 유무로 테스트 실행을 판정한다. **XCUITest 는 러너와 앱이 별개 프로세스라 앱 프로세스엔 이 변수가 심기지 않는다** — 현 상태로 e2e 를 돌리면 앱이 실제 `models.db` 를 열고 Firebase·AdMob 을 켠다.

  ```swift
  static var isTestBuild: Bool {
  #if DEBUG
      return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  #endif
      return false
  }
  ```

- `isTestBuild` 소비처는 7곳이고 성격이 둘로 갈린다:

  | file:line | 용도 | e2e 에서 기대값 |
  |---|---|---|
  | `AppDelegate.swift:30` | Firebase configure·FCM delegate·푸시 등록 차단 | 차단 (참) |
  | `Factories/ApplicationBase.swift:100` | FirebaseAuth → `DummyFirebaseAuthService` | 차단 (참) |
  | `Factories/ApplicationBase.swift:180` | AdMob → `DummyMobileAdService` | 차단 (참) |
  | `AppEnvironment.swift:22` (`dbFileName`) | DB 파일명 `test_dummy` | 차단 (참) |
  | `Root/ApplicationRootRouter.swift:294` | `setupInitialScene` 에서 `guard !isTestBuild else { return nil }` — 실제 화면 억제 | **억제 안 함 (거짓)** |
  | `AppExtensions/Base/AppExtensionBase.swift:68` | 확장 타겟 판정 | 이번 범위 밖 |

  `AppEnvironment.swift:22` 는 `dbFileName` 안에서 `isTestBuild` 를 부르는 자리이고 `dbFilePath(for:)` (`:39`) 가 그걸 탄다.

- Firebase·FCM·푸시·AdMob 차단 배선은 **이미 존재한다.** 신규 분기를 만드는 게 아니라 위 네 자리의 술어만 바꾸는 일이다.
- `ApplicationRootRouter.setupInitialScene` 이 `nil` 을 반환하면 `refreshRoot()` (`:388-403`) 가 안 돌아 `window.rootViewController` 가 안 붙는다 — e2e 에서 이 가드가 참이면 화면이 안 떠 검증 대상이 사라진다.
- Tuist `makeAppTargets` (`Tuist/ProjectDescriptionHelpers/Project+Templates.swift:207`) 는 app 타겟과 `<name>Tests` (`.unitTests`) 만 만든다. `.uiTests` product 타겟이 이 프로젝트에 하나도 없다.
- **동형 구현**: `makeSnapshotsTarget` (`Project+Templates.swift:113`) 이 정확히 같은 모양이다 — `<name>Snapshots` 이름, 전용 소스 디렉토리 `["Snapshots/**"]`, `.target(name: name)` 의존, `infoPlist: .default`. e2e 타겟은 product 가 `.uiTests` 인 것만 다르다.
- `Project.app(...)` (`Project+Templates.swift:12`) 시그니처는 `name·destinations·iOSTargetVersion·dependencies·extensionTargets·schemes` 다. `frameworkWithTest(... snapshotTests: Bool = false ...)` (`:47`) 가 옵션 플래그로 타겟을 덧붙이는 선례다.
- Tuist 스킴 접기 — `<Target>Tests` 이름은 `<Target>` 스킴의 TestAction 으로 접히고, 다른 이름(`<Target>Snapshots` 선례)은 독립 스킴이 된다.
- 앱 타겟 Info.plist 에 `NSAppTransportSecurity.NSAllowsArbitraryLoads = true` 가 이미 있다 (`Project+Templates.swift:225`) — DP-1.2 의 로컬 스텁 서버에 ATS 추가 설정이 필요 없다. 이 태스크에서 건드릴 일은 없다.
- CLAUDE.md §1 짝규칙 문언 (`CLAUDE.md:13`): "신규 테스트 스킴 ↔ 스킴 목록 하드코딩 전부 (`pr_test.yml` 3곳·`scripts/run-all-tests.sh`·`impact-check.sh`·`run-tests` 스킬 — 단 `<Name>Snapshots` 스킴은 의도된 예외 — 로컬 전용, snapshot-check 스킬)". e2e 스킴도 로컬 전용이지만 **문언상 예외가 아니다.**
- `.claude/rules/testability.md` §8 도 같은 상태다 — "테스트 소스는 각 프레임워크의 `Tests/` 밑 … 예외: 스냅샷 캡처 스위트는 최상위 `Snapshots/`". `E2E/` 배치는 문언상 예외가 아니다.

### 나. 장애·마찰

**유력한 양상** — 판정축을 넓히다 화면 억제(`ApplicationRootRouter.swift:294`)까지 같이 넘기면, 기존 유닛 테스트에서 실제 화면이 뜬다. 소비처 7곳에 두 성격이 한 이름으로 얹혀 있어 오분류 여지가 크다.

**반드시 피해야 할 함정 — HTTP 종단을 안 막고 스모크를 돌리는 것.** 기존 `isTestBuild` 차단 배선은 SDK·DB 만 덮고 HTTP 를 안 덮는다. 앱이 뜨면 `CalendarViewModel.swift:317` → `HolidayUsecaseImple.prepare()` 가 자동으로 돌아 `HolidayRepositoryImple.swift:145` 의 `holidays` 를 **실 `calendarAPIHost` 로** 호출한다. 축을 SDK·DB 까지만 넓힌 채 T-3 을 실행하면 그 순간 실제 API 가 나간다 — 유저 지시 (3) 위반이다. 그래서 이 명령은 host 종단을 T-1 에 포함한다 (아래 3-가 핵심과업 세 번째).

**가장 위험한 양상** — 유닛 테스트가 조용히 깨지는데(크래시가 아니라 타이밍·상태 오염) 이 브랜치에선 안 드러나고 develop 머지 후 다른 PR 에서 터지는 것.

### 다. 상위 인용

campaign.md #826 에서:

- **최종상태 관련 관점** — 코드: "프로덕션 코드의 e2e 관련 개입이 판정축 1개 + host 주입 1곳으로 끝나 있다" / 구조: "e2e 타겟이 독립 스킴을 갖고 기존 유닛 테스트 스킴(`TodoCalendarApp`)에 섞이지 않는다"
- **노력선 중간 목표** — LOE-1 ① 앱이 e2e 실행을 인지한다 → ② 외부 SDK 가 e2e 에서 돌지 않는다 / LOE-3 ① e2e 타겟·독립 스킴이 생긴다
- **인접 DP 관계·인터페이스 계약** (campaign 8항 통제수단) — "DP-1.1 → DP-1.2: 앱이 e2e 를 인지하는 **실행 인자 키**와, 러너가 host 를 주입하는 **환경변수 키** 두 이름을 DP-1.1 이 확정해 공개한다. DP-1.2 는 그 키에만 의존한다."
- **제한 인용** (campaign 15·16항) — "기존 `isTestBuild` 의 이름과 동작을 바꾸지 않는다 — 축을 추가하는 방식으로만 확장한다" / "각 SDK·API 호출부마다 e2e 분기를 개별 추가하지 않는다" / "e2e 를 기존 `TodoCalendarApp` 스킴 TestAction 에 넣지 않는다" / "CI 워크플로우 파일을 건드리지 않는다"

### 라. 가정

| ID | 가정 | 출처 | 깨지면 |
|---|---|---|---|
| A-3 | `Tests` 로 끝나지 않는 이름의 테스트 타겟은 Tuist 가 독립 스킴으로 만든다 | 상속 (campaign 11항) | 이 명령 안에서 `Project.app(schemes:)` 에 스킴을 명시 정의로 전환. 부록 D 단편명령 불요 — 우발계획 U-1 |
| A-5 | 판정축 분리 후에도 기존 유닛 테스트 스킴이 전건 통과한다 (화면 억제 판정이 안 뒤집힘) | 상속 (campaign 11항) | 이 명령 안에서 축 분리 재설계 — 우발계획 U-2 |
| A-7 | `ProcessInfo.processInfo.arguments` 에 XCUITest `launchArguments` 가 그대로 실린다 | 신규 | T-3 에서 즉시 드러난다(스모크가 격리 없이 뜸). 인지 수단을 `launchEnvironment` 로 전환 — 우발계획 U-3 |
| A-8 | e2e 타겟이 `.uiTests` product 라도 앱 타겟에 `.target(name:)` 의존만으로 배선된다 (테스트 호스트 별도 지정 불요) | 신규 (`makeSnapshotsTarget` 동형에서 유추, product 만 다름) | T-2 에서 빌드 실패로 드러난다. Tuist `.uiTests` 배선 문서 확인 후 보정 — 자율 |

### 마. 인접 작업

없음. DP-1.2 는 이 DP 머지 후 착수라 동시 진행이 아니고, 소유 범위가 겹치는 `ApplicationBase.swift` 도 순차 접근이다.

## 2. 임무

이 작업은 **e2e 스킴으로 앱이 실행돼 화면이 뜨고 기존 유닛 테스트가 전건 통과할 때까지**, `isTestBuild` 를 외부 의존 차단 축과 화면 억제 축으로 **분리**하고 uiTests 타겟·독립 스킴을 **신설**하여, DP-1.2 가 픽스처를 주입할 격리된 실행 종단을 확보한다.

## 3. 실시

### 가. 의도

**목적** — DP-1.2 가 스텁 서버를 붙일 수 있는 자리를 만든다. 이 DP 자체는 픽스처를 다루지 않는다.

**핵심과업** (성립 조건)

- e2e 실행 중 앱이 Firebase·FCM·푸시·AdMob 을 켜지 않고 실 DB 파일을 열지 않는다.
- e2e 실행 중 앱이 실 `calendarAPIHost` 로 HTTP 요청을 내보내지 않는다 — 스모크를 처음 돌리는 그 순간부터 성립해야 한다.
- e2e 실행 중 앱 화면은 정상적으로 뜬다 (유닛 테스트의 화면 억제와 다르게 동작한다).
- e2e 가 기존 유닛 테스트 스킴에 섞이지 않는다.
- 기존 유닛 테스트의 동작이 하나도 안 바뀐다.

**최종상태**

- 동작: `xcodebuild test -workspace TodoCalendar.xcworkspace -scheme TodoCalendarAppE2E` 로 앱이 뜨고 스모크가 통과한다
- 코드: 프로덕션 변경이 `AppEnvironment` 의 계산 프로퍼티 2개 추가 + 소비처 4곳 술어 교체 + `remoteEnvironment` host 분기 1곳으로 끝난다 (campaign 4항 "판정축 1개 + host 주입 1곳"과 일치)
- 구조: `TodoCalendarAppE2E` 가 독립 스킴을 갖고 `TodoCalendarApp` 스킴 TestAction 에 안 들어간다
- 검증: 영향 스킴 유닛 테스트가 전건 통과한다
- 외부: 없음

### 나. 개념

**결정적 행동** — `AppEnvironment` 에 `isExternalDependencyBlocked` 를 세우고, 외부 의존 차단 4곳의 술어를 그것으로 바꾸는 동시에 `remoteEnvironment` 의 host 를 그 축 아래로 넣는다. SDK·DB·HTTP 셋이 한 축으로 끊겨야 차단이 완결된다. 나머지는 이 행동이 성립하도록 만드는 여건 조성이다.

**여건 조성** — e2e 타겟·스킴을 세워 결정적 행동이 실제로 걸렸는지 확인할 수단을 만든다(T-2·T-3). 하네스 문언을 실제와 맞춘다(T-4).

**대안 경로 + 전환 조건** — A-3 이 깨지면(자동 생성 스킴이 안 생기거나 `TodoCalendarApp` 에 접힘) `Project.app(schemes:)` 로 스킴을 명시 정의한다. 전환 조건은 T-2 의 `xcodebuild -list` 확인 결과다.

**단계** — 단일 단계(선형). 요도 없음 — 태스크 의존이 T-1 → T-2 → T-3 → T-4 로 선형이고 분기 체인이 없다.

### 다. 과업

- **T-1**: `AppEnvironment` 에 e2e 실행 인지와 외부 의존 차단 축을 **추가**하고, 차단 소비처 4곳의 술어를 **교체**하며 `remoteEnvironment` 의 host 를 그 축 아래로 **편입**하여, 앱이 XCUITest 실행에서 SDK·DB·HTTP 를 모두 끊게 한다.
- **T-2**: Tuist 팩토리에 `.uiTests` 타겟 생성 경로를 **추가**하고 앱 프로젝트에 **배선**하여, 독립 e2e 스킴을 확보한다.
- **T-3**: 콜드런치 기동을 확인하는 스모크 1건을 **작성**하여, 격리 종단이 실제로 도는지 검증한다.
- **T-4**: CLAUDE.md 짝규칙과 testability.md 배치 규칙 문언에 e2e 예외를 **보갱**하여, 다음 사람이 누락으로 오독하지 않게 한다.

### 라. 협조지시

**개시 조건** — 작전계획 재가 완료(충족), 선행 DP 없음.

**인터페이스 계약 (상속 + 추가)** — campaign 8항 통제수단을 이 명령이 다음 값으로 확정한다. DP-1.2 는 이 두 이름에만 의존한다:

| 용도 | 키 | 이 DP 에서의 취급 |
|---|---|---|
| e2e 실행 인지 (러너 → 앱) | 실행 인자 `-uiTest` | T-1 에서 `isUITestRun` 이 읽는다. T-3 이 `app.launchArguments` 로 전달한다 |
| API host 주입 (러너 → 앱) | 환경변수 `E2E_API_HOST` | T-1 에서 `remoteEnvironment` 가 읽는다. 미설정이면 도달 불가 주소로 떨어져 실 API 를 안 탄다 — DP-1.2 는 이 값을 채우기만 하므로 **프로덕션 코드 변경이 없다** |

**제한**

- `isTestBuild` 의 이름·본문·반환 동작을 바꾸지 않는다 (이유: campaign 15항. 소비처 7곳과 확장 타겟까지 번져 범위를 벗어난다).
- `ApplicationRootRouter.swift:294` 와 `AppExtensionBase.swift:68` 의 술어를 바꾸지 않는다 (이유: 화면 억제 축이고, e2e 는 화면이 떠야 검증 대상이 생긴다. 확장 타겟은 범위 밖).
- CI 워크플로우 파일(`.github/workflows/*`)과 `scripts/run-all-tests.sh`·`impact-check.sh` 에 e2e 스킴을 등재하지 않는다 (이유: campaign 0항 결심 — 로컬 전용. T-4 가 이 사실을 문언으로 명시한다).
- 픽스처와 스텁 서버를 만들지 않는다 (이유: DP-1.2 소관). host **주입 자리**는 이 태스크가 뚫는다 — 그게 없으면 T-3 스모크가 실 API 를 타서 유저 지시 (3) 을 어긴다. 소비자가 지금 생기므로 YAGNI 대상이 아니다.

**위임 범위** (좁히는 것만)

- 프로덕션 코드 수정은 `AppEnvironment.swift`·`AppDelegate.swift`·`ApplicationBase.swift` 세 파일의 위 목적으로 한정. 그 밖의 프로덕션 파일을 고쳐야 하면 즉시보고 후 재가.
- 하네스 문서 수정은 `CLAUDE.md` §1 짝규칙 줄과 `.claude/rules/testability.md` §8 두 자리로 한정 (유저 재가로 소유 범위가 이만큼 넓혀진 상태다).

**수용 위험** — `isTestBuild` 라는 이름이 분리 후 "화면 억제"만 뜻하게 돼 이름과 의미가 어긋난 채 남는다. campaign 15항이 이름 변경을 금지하므로 이번엔 수용한다.

**버퍼** — 자율 등급: 위 제한·위임 범위 안에서 구현 방법은 전적으로 실행자 재량. 아래 우발계획의 조건에 걸리면 그 행동을 취한다.

**즉시보고 조건**

| 조건 | 구분 | 결정지점 |
|---|---|---|
| `tuist generate` 후 e2e 스킴이 독립으로 안 생기거나 `TodoCalendarApp` 스킴에 접힘 | FFIR-1 | D-1 |
| 영향 스킴 유닛 테스트에 신규 실패가 발생 | FFIR-2 | D-2 |
| `-uiTest` 인자가 앱 프로세스의 `ProcessInfo.arguments` 에 안 실림 | FFIR-3 | D-3 |
| 스모크 실행 중 실 `calendarAPIHost` 로 요청이 나간 흔적 | FFIR-5 | D-4 |
| 제한·위임 판단이 갈리는데 대응 rules 조항이 없음 → 하네스 갭 | FFIR-4 | 재가 상향 |

**결정지점**

| ID | 결정 | 판단 정보 | 시한 (조건) | 미결 시 기본 행동 |
|---|---|---|---|---|
| D-1 | 스킴을 자동 생성에 맡기나 `Project.app(schemes:)` 로 명시 정의하나 | `xcodebuild -list` 출력 | T-2 완료 시점 | 명시 정의로 전환 — 스킴 분리는 최종상태 구조 관점이라 자동 생성에 의존해 미달하면 안 된다 |
| D-2 | 신규 실패가 축 분리 탓인가 기존 플레이키인가 | 실패 테스트명 + 단독 재실행 결과 + 메모리의 잔여 플레이키 목록 | T-1 완료 직후 | 단독 재실행으로 갈라 판정. 축 분리 탓이면 U-2 |
| D-3 | e2e 인지 수단을 실행 인자로 두나 환경변수로 바꾸나 | T-3 스모크에서 격리가 걸렸는지 | T-3 최초 실행 시점 | `launchEnvironment` 로 전환하고 계약 표를 갱신 — 인지 수단은 목적이 아니라 방법이다 |
| D-4 | 실 API 요청이 새는 자리가 host 분기 누락인가 다른 경로인가 | 요청 URL + `RemoteEnvironment.path` (`Endpoint.swift:355~`) 의 해당 case | T-3 최초 실행 시점 | 즉시 중단하고 새는 경로를 특정해 host 종단에 편입. gist(`supportCountry`)는 campaign 0항 결심으로 수용 대상이라 제외 |

**우발계획**

| 조건 | 행동 | 결심자 | 상향 |
|---|---|---|---|
| U-1: A-3 붕괴 (스킴 자동 생성 실패) | `Project.app(schemes:)` 에 e2e 스킴을 명시 정의 | 실행자 | 불요 |
| U-2: A-5 붕괴 (축 분리로 유닛 테스트 깨짐) | 어느 소비처가 뒤집혔는지 특정해 술어를 되돌리고 재분류 | 실행자 | 되돌려도 안 풀리면 유저 |
| U-3: A-7 붕괴 (`-uiTest` 미전달) | 인지 수단을 `launchEnvironment` 로 전환, 계약 표(3-라)를 갱신하고 부록 D 에 단편명령으로 기록 | 실행자 | 불요 (사후보고) |
| U-4: A-8 붕괴 (`.uiTests` 배선 실패) | 테스트 호스트 지정 등 Tuist `.uiTests` 요건을 보정 | 실행자 | 불요 |

## 4. 검증·자원

**테스트 스킴·검증 사다리**

1. `tuist generate --no-open` 후 `xcodebuild -list -workspace TodoCalendar.xcworkspace` — `TodoCalendarAppE2E` 가 독립 스킴으로 있고 `TodoCalendarApp` 스킴 TestAction 에 안 들어갔는지 확인 (A-3·최종상태 구조)
2. `xcodebuild test -workspace TodoCalendar.xcworkspace -scheme TodoCalendarAppE2E -destination <시뮬레이터>` — 스모크 통과 (최종상태 동작)
3. **영향 스킴 유닛 테스트** — `.claude/skills/implement/scripts/impact-check.sh` 로 변경 경로에서 스킴을 계산해 실행 (A-5·최종상태 검증). `TodoCalendarApp` 은 반드시 포함된다
4. 실패 진단이 필요하면 스킴을 한 번에 묶어 로그 파일로 받고 grep — 스킴별 재실행 금지

**스냅샷·실기** — 없음.

**모델 티어·병렬 슬롯·워크트리** — 부록 C. 인라인 실행(이 세션), 병렬 슬롯·워크트리 없음.

**외부 자원** — 시뮬레이터 1대. 외부 계정 불요.

## 5. 보고

- **즉시** — 3-라 즉시보고 조건(FFIR-1~4) 발생 시, 가정 A-3·A-5·A-7·A-8 붕괴 시, 하네스 갭 발견 시.
- **정기** — 태스크(T-1~T-4) 완료마다 진행 파일 갱신 + 이슈 본문 미러 재조립.
- **유저 부재 시** — 의도(3-가) 안이면 결정지점의 기본 행동으로 계속한다. **중단 조건**: U-2 를 되돌려도 유닛 테스트가 안 풀릴 때, 제한을 어겨야만 진행되는 상황일 때.
- **종결 조건** — 4항 검증 사다리 3단이 모두 통과하고 부록 B 커밋이 완료되면 pr 스킬로 전이해 종결보고를 낸다.

---

## 부록 A. 태스크 상세

### Task 1: AppEnvironment 판정축 분리

**Files**
- Modify: `TodoCalendarApp/Sources/AppEnvironment.swift`
- Modify: `TodoCalendarApp/Sources/AppDelegate.swift`
- Modify: `TodoCalendarApp/Sources/Factories/ApplicationBase.swift`
- Test: 없음 (기존 유닛 테스트가 회귀 가드다 — 4항 검증 사다리 3단)

**Interfaces**
- Produces: `AppEnvironment.isUITestRun`, `AppEnvironment.isExternalDependencyBlocked`, 그리고 `E2E_API_HOST` 를 읽는 host 분기 — T-3 이 `-uiTest` 트리거를 쓰고, DP-1.2 는 `E2E_API_HOST` 에 스텁 주소를 넣기만 한다.
- Consumes: 없음

**시그니처**

```swift
// TodoCalendarApp/Sources/AppEnvironment.swift — 기존 isTestBuild 는 이름·본문 그대로 둔다
static var isUITestRun: Bool
static var isExternalDependencyBlocked: Bool   // isTestBuild || isUITestRun
```

`isUITestRun` 은 `isTestBuild` (`:16`) 와 같은 `#if DEBUG` 형태로 쓴다 — Release 에서 항상 `false` 여야 e2e 스위치가 배포 빌드에 살아남지 않는다. 판정 입력은 `ProcessInfo.processInfo.arguments` 의 `-uiTest` 포함 여부다.

**술어 교체 대상** (이 넷만. 나머지 셋은 3-라 제한)

| file:line | 현재 | 교체 후 |
|---|---|---|
| `AppDelegate.swift:30` | `if AppEnvironment.isTestBuild == false {` | `if AppEnvironment.isExternalDependencyBlocked == false {` |
| `ApplicationBase.swift:100` | `if AppEnvironment.isTestBuild {` | `if AppEnvironment.isExternalDependencyBlocked {` |
| `ApplicationBase.swift:180` | `if AppEnvironment.isTestBuild {` | `if AppEnvironment.isExternalDependencyBlocked {` |
| `AppEnvironment.swift:22` (`dbFileName`) | `if self.isTestBuild {` | `if self.isExternalDependencyBlocked {` |

**host 종단** — `ApplicationBase.swift:87-89` 의 host 결정에 차단 축을 얹는다. 현재는 `useEmulator` 로만 갈린다:

```swift
let host = AppEnvironment.useEmulator
    ? secrets["emulator_caleandar_api_host"] as? String
    : secrets["caleandar_api_host"] as? String
```

차단 시 `E2E_API_HOST` 를 읽고, 없으면 **도달 불가 주소**(`http://127.0.0.1:1` — 포트 1 은 예약이라 즉시 connection refused, 타임아웃 대기가 없다)로 떨어뜨린다. `csAPI` 는 콜드런치가 안 타므로 건드리지 않는다.

이 분기가 campaign 4항이 허용한 "host 주입 1곳"이고, DP-1.2 는 이 환경변수에 스텁 주소를 넣기만 하므로 프로덕션 코드를 안 건드린다.

**엣지 케이스**

| 상황 | 기대 동작 |
|---|---|
| 일반 실행 (인자 없음) | `isUITestRun` false, `isExternalDependencyBlocked` false → 기존 프로덕션 경로 그대로 |
| 유닛 테스트 (XCTest) | `isTestBuild` true → `isExternalDependencyBlocked` true (차단 유지), `isTestBuild` 로 남은 화면 억제도 true. 다만 host 는 실 host 가 아니라 `blockedAPIHost` 로 바뀐다 — `ApplicationBase` 를 유닛 테스트가 조립하지 않아 실질 영향은 없고, 실 host 를 안 타게 되는 쪽이 낫다 |
| e2e (`-uiTest`), `E2E_API_HOST` 미설정 | 차단 참 → host 가 `http://127.0.0.1:1` → `holidays` 호출이 즉시 connection refused. `CalendarViewModel.swift:317` 의 `try?` 가 삼켜 화면은 정상적으로 뜬다. **실 API 로는 안 나간다** |
| e2e (`-uiTest`), `E2E_API_HOST` 설정 | 차단 참 → host 가 그 값. DP-1.2 의 스텁 서버가 여기로 들어온다 |
| e2e (`-uiTest`) | `isUITestRun` true → 차단 참, 화면 억제는 `isTestBuild` 가 false 라 거짓 → 화면이 뜬다 |
| Release 빌드 | `#if DEBUG` 밖이라 `isUITestRun` false → e2e 스위치 무효 |

**Steps**
- [ ] Step 1: `AppEnvironment` 에 `isUITestRun`·`isExternalDependencyBlocked` 추가 (`isTestBuild` 바로 아래, `#if DEBUG` 형태를 `:16` 과 맞춤)
- [ ] Step 2: `dbFileName` (`:22`) 술어를 `isExternalDependencyBlocked` 로 교체
- [ ] Step 3: `AppDelegate.swift:30` 술어 교체
- [ ] Step 4: `ApplicationBase.swift:100`·`:180` 술어 교체
- [ ] Step 5: `ApplicationBase.swift:87-89` host 결정에 차단 축 분기 추가 (`E2E_API_HOST` → 없으면 `http://127.0.0.1:1`)
- [ ] Step 6: `grep -rn "isTestBuild" TodoCalendarApp/` 로 남은 소비처가 `ApplicationRootRouter.swift:294`·`AppExtensionBase.swift:68` 둘뿐인지 확인
- [ ] Step 7: `.claude/skills/implement/scripts/impact-check.sh` 로 영향 스킴을 계산해 유닛 테스트 실행 (A-5). 신규 실패가 나오면 D-2 판정 후 U-2
- [ ] Step 8: 부록 B 커밋 2

### Task 2: e2e 타겟·스킴 배선

**Files**
- Modify: `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`
- Modify: `TodoCalendarApp/Project.swift`
- Create: `TodoCalendarApp/E2E/` (T-3 이 파일을 채운다 — 이 태스크는 디렉토리와 배선까지)

**Interfaces**
- Produces: `TodoCalendarAppE2E` 타겟·독립 스킴, 소스 루트 `TodoCalendarApp/E2E/**` — T-3 이 여기에 스모크를 놓는다
- Consumes: 없음

**시그니처**

```swift
// Tuist/ProjectDescriptionHelpers/Project+Templates.swift
public static func app(
    name: String,
    destinations: Destinations,
    iOSTargetVersion: String,
    dependencies: [TargetDependency] = [],
    extensionTargets: [Target] = [],
    schemes: [Scheme] = [],
    e2eTests: Bool = false
) -> Project

private static func makeE2ETarget(
    name: String,
    destinations: Destinations,
    iOSTargetVersion: String
) -> Target
```

`e2eTests` 기본값 `false` 로 두면 다른 `Project.app` 호출처가 안 깨진다. `frameworkWithTest(... snapshotTests: Bool = false ...)` (`Project+Templates.swift:47`) 가 같은 패턴의 선례다.

**동형 구현** — `makeSnapshotsTarget` (`Project+Templates.swift:113`). 그대로 따르되 셋만 다르다: 이름 `"\(name)E2E"`, product `.uiTests`, sources `["E2E/**"]`. 의존은 `[.target(name: name)]` 하나 (스냅샷 타겟이 끌어오는 `SnapshotTestHelpKit`·`TestDoubles` 는 e2e 에 불요 — XCUITest 는 앱 내부 타입에 접근하지 않는다).

**엣지 케이스**

| 상황 | 기대 동작 |
|---|---|
| 이름이 `TodoCalendarAppE2E` (`Tests` 로 안 끝남) | Tuist 가 독립 스킴 생성 (A-3, `<Name>Snapshots` 선례) |
| A-3 붕괴 — `TodoCalendarApp` 스킴에 접힘 | D-1 → U-1: `Project.app(schemes:)` 에 명시 정의 |
| `.uiTests` 가 테스트 호스트를 요구 | A-8 붕괴 → U-4: Tuist `.uiTests` 요건 보정 |
| `E2E/` 가 비어 있는 상태로 generate | 타겟은 생기되 테스트 0건 — T-3 전까지 정상 상태다 |

**Steps**
- [ ] Step 1: `makeE2ETarget` 을 `makeSnapshotsTarget` (`:113`) 바로 아래에 추가
- [ ] Step 2: `Project.app` 시그니처에 `e2eTests: Bool = false` 추가하고, 참이면 `targets` 에 `makeE2ETarget` 결과를 덧붙임
- [ ] Step 3: `TodoCalendarApp/Project.swift` 의 `Project.app(...)` 호출에 `e2eTests: true` 전달
- [ ] Step 4: `TodoCalendarApp/E2E/` 디렉토리 생성
- [ ] Step 5: `tuist generate --no-open` 실행 후 `xcodebuild -list -workspace TodoCalendar.xcworkspace` 로 스킴 분리 확인 (검증 사다리 1단). 접혀 있으면 D-1 → U-1
- [ ] Step 6: 커밋하지 않는다 — T-3 과 묶여 부록 B 커밋 3 이 된다

### Task 3: 콜드런치 기동 스모크

**Files**
- Create: `TodoCalendarApp/E2E/AppLaunchE2ETests.swift`

**Interfaces**
- Consumes: `AppEnvironment.isUITestRun` 의 트리거 `-uiTest` (T-1), `TodoCalendarAppE2E` 타겟 (T-2)
- Produces: e2e 스모크 실행 커맨드 — DP-1.2 종결보고가 이걸 이어받아 확장한다

**시그니처**

```swift
final class AppLaunchE2ETests: XCTestCase {
    func test_whenLaunchAsUITestRun_appShowsRootWindow() throws
}
```

`XCUIApplication()` 에 `launchArguments += ["-uiTest"]` 를 실어 실행하고, 루트 윈도우가 뜨는지 `waitForExistence(timeout:)` 로 확인한다.

**따라야 할 rules 조항** (실행 서브에이전트는 path 자동 로드를 못 받으므로 발췌)

- `.claude/rules/testability.md` §6 — "모든 테스트 메서드에 `// given / when / then` 구조 표시."
- `.claude/rules/testability.md` §6 — "Observable behavior만 검증. private state 검증 금지." XCUITest 는 UI 요소 존재·상태만 본다. 격리가 걸렸는지를 앱이 노출하게 만들지 않는다 (campaign 16항 프로덕션 오염 금지와 같은 결).
- `.claude/rules/testability.md` §9 — "고정 sleep 금지. 조건이 참이 될 때까지 폴링한다." XCUITest 에서는 `waitForExistence(timeout:)`·`XCTNSPredicateExpectation` 이 그 수단이다. `Thread.sleep`·`sleep()` 금지.

**엣지 케이스**

| 상황 | 기대 동작 |
|---|---|
| 앱이 안 뜨거나 크래시 | 테스트 실패. 격리 축이 안 걸린 것이므로 D-3 판정 |
| 윈도우는 뜨는데 내용이 비어 있음 | 이 DP 는 루트 윈도우 존재까지만 단언한다. 캘린더 렌더 단언은 DP-1.2 소관 (픽스처가 있어야 성립) |
| 실행이 3분을 넘김 | campaign 12항 작전한계점의 지표지만, 판정은 DP-1.2 스모크 완성 후다. 여기선 사실만 기록 |
| 실 API 로 요청이 나감 | T-1 host 종단이 안 걸린 것. 즉시 중단하고 FFIR-5 로 보고 — 유저 지시 (3) 위반이라 진행보다 우선한다 |

**테스트 케이스 이름**
- `test_whenLaunchAsUITestRun_appShowsRootWindow`

**Steps**
- [ ] Step 1: `AppLaunchE2ETests.swift` 작성 (given/when/then 주석 포함)
- [ ] Step 2: `xcodebuild test -workspace TodoCalendar.xcworkspace -scheme TodoCalendarAppE2E -destination <시뮬레이터>` 실행 (검증 사다리 2단)
- [ ] Step 3: 격리가 안 걸렸으면(앱이 실 DB·Firebase 를 물면) D-3 판정 후 U-3
- [ ] Step 4: 부록 B 커밋 3 (Task 2+3 묶음)

### Task 4: 로컬 전용 스킴 예외 문언 보갱

**Files**
- Modify: `CLAUDE.md` (§1 짝규칙, `:13`)
- Modify: `.claude/rules/testability.md` (§8 테스트 파일 배치)

**Interfaces**
- Consumes: T-2 가 확정한 타겟 이름 `TodoCalendarAppE2E` 와 소스 경로 `E2E/**`
- Produces: 없음

**변경 내용**

- `CLAUDE.md:13` — 현재 "단 `<Name>Snapshots` 스킴은 의도된 예외 — 로컬 전용, snapshot-check 스킬" 에 e2e 스킴을 같은 예외로 추가한다. **예외인 이유(로컬 전용)를 함께 적는다** — 이유 없이 이름만 늘리면 다음 사람이 판단 근거를 못 얻는다.
- `.claude/rules/testability.md` §8 — 소스 배치 예외에 `E2E/**` 를 추가한다 (현재는 `Snapshots/` 만 예외).

**엣지 케이스**

| 상황 | 기대 동작 |
|---|---|
| 나중에 CI 배선 이슈가 서면 이 예외가 뒤집힌다 | 그때 그 이슈가 문언을 되돌린다. 지금 "나중에 바뀔 수 있음" 같은 유보를 적지 않는다 — 문언은 현재 확정 상태만 담는다 |

**Steps**
- [ ] Step 1: `CLAUDE.md:13` 짝규칙 줄에 e2e 스킴 예외 추가 (이유 병기)
- [ ] Step 2: `.claude/rules/testability.md` §8 에 `E2E/**` 배치 예외 추가
- [ ] Step 3: 부록 B 커밋 4

## 부록 B. 커밋 시퀀스

| # | 대응 태스크 | 메시지 |
|---|---|---|
| 1 | (문서) | `[#826] e2e 구성 작전계획과 DP-1.1 작전명령 수립`<br>— `docs/operations/826/campaign.md` + `docs/operations/1054/opord-DP-1.1.md`. 진행 파일(`.operations/**`)은 gitignore 대상이라 안 싣는다 |
| 2 | Task 1 | `[#1054] XCUITest 실행에서도 외부 의존이 차단되도록 판정축 분리`<br>— `AppEnvironment.isUITestRun`·`isExternalDependencyBlocked` 추가, 차단 4곳 술어 교체. 화면 억제는 `isTestBuild` 로 남겨 유닛 테스트 동작 불변 |
| 3 | Task 2+3 | `[#1054] e2e 전용 타겟·독립 스킴 신설과 콜드런치 기동 스모크`<br>— `Project.app(e2eTests:)` 로 `.uiTests` 타겟 생성, `TodoCalendarAppE2E` 스킴에서 앱 기동 확인 |
| 4 | Task 4 | `[#1054] 로컬 전용 스킴·소스 배치 예외에 e2e 를 명시` |

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| T-1 | 하위 (haiku급) | 시그니처·교체 대상 file:line 이 표로 확정됨. 3파일 |
| T-2 | 표준 (sonnet급) | Tuist 팩토리 구조 이해 + 동형 구현 이식 + generate 결과 검증 |
| T-3 | 표준 (sonnet급) | XCUITest 관용구 + 실행·판정 |
| T-4 | 하위 (haiku급) | 두 줄 문언 수정 |

## 부록 D. 단편명령

없음.
