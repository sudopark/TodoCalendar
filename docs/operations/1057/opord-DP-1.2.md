# 작전명령 — #1057 스텁 HTTP 서버와 콜드스타트 스모크 완성

```
작전명령 — #1057 스텁 HTTP 서버와 콜드스타트 스모크 완성    초안: 에이전트   재가: 유저   일자: 2026-09-08
상위: campaign.md #826 / LOE-2 / 1단계 / DP-1.2 / 선행 DP-1.1 (머지 a713941e)
```

## ■ 확인보고

**임무 내 말로** — 러너 프로세스에 스텁 HTTP 서버를 세워 콜드런치가 요구하는 홀리데이 응답을 공급하고, 그 응답이 캘린더 월 그리드까지 그려진 것을 단언하는 스모크를 완성한다. 실 API host 로는 한 건도 안 나간다.

**의도** — 이번 작업의 값은 통과하는 테스트 하나가 아니라 **다음 시나리오가 붙을 자리**다. 스텁 서버·픽스처·베이스 케이스를 e2e 타겟 소유로 세워, 이후 시나리오가 픽스처 파일과 시나리오 파일만 추가하면 되게 만든다.

**자율로 정할 것** — 스텁 서버 내부 구조(연결 처리·파싱 방식), 픽스처 로더 형태, 태스크 순서·커밋 시퀀스 조정.

**묻는 것** — 없음. 유저 결심 5건(단언 수단·미등록 요청 처리·픽스처 형식·서버 수명주기·상태 초기화)은 이미 받았고 계획 개정에 반영했다.

---

## 1. 상황

### 가. 정찰 결과

- **미로그인 콜드런치가 `calendarAPIHost` 로 내는 요청은 홀리데이 GET 한 건이다.** `HolidayRepositoryImple.loadHolidaysFromRemote`(`Repository/Sources/Repository+Imple/Calendar/HolidayRepositoryImple.swift:137-150`) → `GET {host}/v2/holiday?year=&locale=&code=` (`Endpoint.swift:383-385`, GET 은 `URLEncoding` 이라 쿼리스트링 — `RemoteAPI.swift:164-167`). 계정 계열은 로컬 auth 가 비어 원격 호출이 없다 (`ApplicationPrepareUsecase.swift:87`).
- **`supportCountry` 는 host 를 안 탄다.** gist 절대 URL 로 나간다 (`Endpoint.swift:379-381`) — 작전계획 0항 D-1 결심으로 실호출 수용. 이 응답의 `regionCode` 와 `Locale.current.region?.identifier`(`HolidayUsecase.swift:49`)가 일치해야 국가가 정해지고, 정해져야 홀리데이 요청이 나간다 (`HolidayUsecase.swift:106-121`).
- **홀리데이는 캐시 우선이다.** `loadHolidays` 가 로컬 캐시가 비었을 때만 원격을 탄다 (`HolidayRepositoryImple.swift:95-103`). 선택 국가도 UserDefaults 에 남는다 (`selectedCountryKey`, `HolidayRepositoryImple.swift:47-56`). e2e DB(`test_dummy.db`)와 UserDefaults suite 는 실행 간 남으므로, 청정화 없이는 2회차부터 스텁을 안 타고 통과한다.
- **응답 스키마** — `{"items":[{"id":..,"summary":..,"start":{"date":"yyyy-MM-dd"}}]}` (`HolidayRepositoryImple.swift:242-268`).
- **단언 대상이 없다.** 코드베이스 전체에 `accessibilityIdentifier` 가 0개다. 월 그리드는 `MonthView.gridWeeksView()`(`Presentations/CalendarScenes/Sources/Month/MonthView.swift:148-162`)가 그리고, 주 데이터가 비면 `emptyGridView()` 로 갈린다. 공휴일은 이벤트 라인으로 들어가 `Text(line.name)`(`MonthView.swift:451`)로 렌더된다.
- **host 주입 자리는 뚫려 있다.** `ApplicationBase.readAPIHost`(`TodoCalendarApp/Sources/Factories/ApplicationBase.swift:85-96`)가 `E2E_API_HOST` 를 읽고, 없으면 `AppEnvironment.blockedAPIHost`(127.0.0.1:1)로 떨어진다.
- **uiTests 타겟에 리소스 자리가 없다.** `makeE2ETarget` 이 `resources: []` 다 (`Tuist/ProjectDescriptionHelpers/Project+Templates.swift:144-160`).

### 나. 장애·마찰

- **유력한 양상** — 픽스처 공휴일 텍스트가 그리드에 렌더되기까지 gist → 국가 선택 → 홀리데이 요청 → 캐시 저장 → 뷰 갱신의 사슬이 길어, 실패했을 때 어느 마디가 끊겼는지 단언만 보고는 안 드러난다. 스텁 서버의 수신 로그가 그 진단 수단이다.
- **가장 위험한 양상** — 상태 청정화가 불완전해 캐시로 초록이 나는 것. 통과했는데 스텁이 한 번도 안 탄 상태라, 픽스처 공급 경로가 죽어도 캠페인 종결까지 안 드러난다.

### 다. 상위 인용

- **최종상태 관련 관점** (campaign 4항) — 동작: "e2e 스킴으로 콜드스타트 스모크를 돌리면 앱이 실행돼 캘린더 루트가 렌더된 것을 단언하고 통과한다". 코드: "프로덕션 코드의 e2e 관련 개입이 판정축 1개 · host 주입 1곳 · 청정 상태 초기화 1곳 · 캘린더 루트 접근성 식별자 1개로 끝나 있다". 품질: "시나리오를 하나 더 추가할 때 픽스처·시나리오 파일만 늘면 된다".
- **노력선 중간 목표** — LOE-2 픽스처 공급: 러너가 응답을 쥐고 앱에 먹인다.
- **인접 DP 관계·인터페이스 계약** (campaign 8항) — DP-1.1 이 `-uiTest`·`E2E_API_HOST` 두 키를 확정·구현했고 이 명령은 후자에 값을 채운다. DP-1.3 에는 **스텁 서버의 미등록 요청 로그**를 검증 수단으로 넘긴다 — 로그가 이 명령의 산출 계약이다.

### 라. 가정

| ID | 가정 | 출처 | 깨지면 |
|---|---|---|---|
| A-1 | 시뮬레이터 앱이 `http://127.0.0.1:<port>` 로 러너의 서버에 붙는다 | 상속 (campaign A-1·A-2) | D-3 → B-3 (픽스처 공급 수단 전환, 계획 개정) |
| A-2 | 미로그인 콜드런치가 타는 RemoteAPI 호출은 `supportCountry`·`holidays` 2건뿐이다 | 상속 (campaign A-4) | D-2 (스텁 대상 편입 또는 DP 추가) |
| A-3 | 시뮬레이터의 지역 코드가 gist `supportCountry` 목록에 있다 | 신규 — 실행 인자로 로케일을 고정해 결정성을 확보한다 | 스텁이 `/v2/holiday` 를 한 번도 못 받는다 → 우발계획 C-1 |
| A-4 | KeyChain 에 로그인 자격이 남아 있지 않다 (미로그인 콜드런치) | 미확인 질문 대체 — KeyChain 삭제는 실 사용자 자격을 지울 위험이 있어 청정화 대상에서 뺐다 | 로그인 상태로 떠 A-2 가 깨진다 → D-2 |

### 마. 인접 작업

없음. DP-1.1 은 머지됐고 DP-1.3 은 미착수다.

---

## 2. 임무

이 작업은 **콜드런치가 요구하는 홀리데이 응답을 러너가 공급할 수 있을 때까지** 스텁 HTTP 서버·픽스처·e2e 베이스·접근성 식별자 카탈로그를 구축하고 캘린더 루트 렌더를 단언하여, **다음 시나리오가 픽스처·시나리오 파일 추가만으로 붙고 단언 대상을 카탈로그 한 곳에서 찾는 기반**을 세운다.

---

## 3. 실시

### 가. 의도

**목적** — e2e 종단의 픽스처 공급 경로를 세우고, 그것이 실제로 화면까지 도달함을 증명한다.

**핵심과업** (성립 조건)
1. 앱이 실 API host 로 요청을 내보내지 않는다 — 모든 `calendarAPIHost` 요청이 러너의 스텁으로 간다.
2. 스텁이 공급한 픽스처가 화면에 도달한 것이 단언으로 드러난다 — 캐시나 우연으로 초록이 나지 않는다.
3. 다음 시나리오가 스텁 기동·주소 주입·정리 배선을 다시 짜지 않는다.
4. 단언 대상 식별자가 한 정본에 모여, e2e 작성자가 화면별로 무엇을 확인할 수 있는지 그 파일만 보고 안다 — 뷰마다 문자열 리터럴을 흩뿌리지 않는다.

**최종상태**
- 동작 — `TodoCalendarAppE2E` 스킴 실행 시 콜드스타트 스모크가 통과하고, 월 그리드 렌더와 스텁의 홀리데이 수신이 단언된다.
- 코드 — 프로덕션 개입이 접근성 식별자 카탈로그 1개(월 그리드 1건 등재) + 청정 초기화 1곳으로 끝난다.
- 구조 — 스텁 서버·픽스처·베이스 케이스가 `TodoCalendarApp/E2E/**` 소유이고 앱 번들에 안 들어간다. 식별자 정본은 `Scenes` 에 있고 앱과 e2e 가 같은 심볼을 본다.
- 검증 — 스텁이 `/v2/holiday` 를 1회 이상 수신했고, 미등록 요청 로그에 실 host 행 요청이 없다.
- 외부 — 없음.

### 나. 개념

**결정적 행동** — 러너가 스텁 서버를 띄우고 그 주소를 `E2E_API_HOST` 로 넘겨 앱을 콜드런치시킨다.

**여건 조성** — (1) 프로덕션에 단언 대상(식별자)과 청정 상태를 마련한다. (2) uiTests 타겟에 리소스 자리를 뚫어 픽스처 JSON 을 싣는다.

**대안 경로 + 전환 조건** — A-1 이 깨져 앱이 러너 서버에 못 붙으면 즉시 중단하고 D-3 로 올린다 (`URLProtocol` 주입·파일 경로 주입 등 수단 전환은 계획 개정 대상이라 이 명령 안에서 처리하지 않는다).

**단계** — 프로덕션 종단 확보 → 스텁 서버 가동 확인 → 픽스처 배선 → 시나리오 단언.

### 다. 과업

- **T-1**: 스텁 HTTP 서버를 자체 구현하여, 러너가 임의의 경로에 JSON 응답을 등록하고 미등록 요청을 기록할 수 있게 한다.
- **T-2**: 접근성 식별자 카탈로그를 정본으로 세워 월 그리드를 등재하고 `-uiTest` 실행이 청정 상태로 시작하게 하여, 단언 대상과 재실행 가능성을 확보한다.
- **T-3**: e2e 타겟에 식별자 정본 의존과 리소스를 배선하고 홀리데이 픽스처 JSON·로더를 두어, 시나리오가 식별자를 심볼로 쓰고 응답 본문을 파일로 관리하게 한다.
- **T-4**: e2e 공용 베이스 케이스를 세우고 콜드스타트 시나리오를 그 위에 올려, 스텁 기동·주소 주입·정리를 시나리오가 상속만으로 얻게 한다.

### 라. 협조지시

**개시 조건** — DP-1.1 머지 완료(a713941e). 충족됐다.

**인터페이스 계약**
- 상속 — `-uiTest` 실행 인자, `E2E_API_HOST` 환경변수 (DP-1.1 확정).
- 추가 — `StubHTTPServer.unhandledRequestPaths` 가 DP-1.3 의 격리 판정 데이터다. 이 이름과 의미를 DP-1.3 까지 유지한다.

**제한**
- 프로덕션 변경은 `Scenes/Sources/AccessibilityID.swift`(신설)·`MonthView.swift`·`AppDelegate.swift` 세 파일, 계획 4항이 센 두 항목으로 한정한다 (이유: campaign 4항 코드 관점이 정량 상태라 누적을 넘기면 판정이 깨진다).
- 식별자 문자열 리터럴을 뷰에 직접 쓰지 않는다 — 카탈로그 심볼만 쓴다 (이유: 리터럴이 흩어지면 e2e 작성자가 확인 대상을 못 찾고, 오타가 컴파일을 안 막는다).
- KeyChain 은 지우지 않는다 (이유: 실 사용자 자격을 지울 위험이 청정화 이득보다 크다 — A-4).
- 외부 캘린더 DB(`google_calendar.db`·`apple__calendar.db`)는 지우지 않는다 (이유: 격리 분기가 없는 실 파일이다. 열리는지 여부는 T-4 에서 mtime 으로 실측하고, 열렸으면 D-2 로 올린다).
- SPM 의존을 추가하지 않는다 (이유: campaign 0항이 자체 구현으로 결심 — 뒤집으려면 A-6 경로).
- 시나리오를 콜드스타트 밖으로 넓히지 않는다 (이유: campaign 16항).

**위임 범위** — campaign 15항 상속. 좁히는 것 없음.

**수용 위험** — gist 실호출 실패 시 스모크가 깨진다 (campaign 12항 수용 결정). 실패 시 스텁 수신 로그가 비어 원인이 즉시 드러난다.

**버퍼** — 자율 등급: 사후보고. 태스크 순서·커밋 시퀀스·서버 내부 구조는 실행자 재량.

**즉시보고 조건**

| 조건 | 구분 | 결정지점 |
|---|---|---|
| 시뮬레이터 앱이 러너 서버에 못 붙음 | FFIR-1 | D-3 |
| 스텁 미등록 요청 로그에 실 host·Firebase·AdMob 행 요청이 남음 | PIR-1 | D-2 |
| 콜드런치가 A-2 밖의 RemoteAPI 호출을 탐 | PIR-2 | D-2 |
| 실 외부 캘린더 DB 가 e2e 실행으로 열림 (mtime 변화) | PIR-3 | D-2 |
| 프로덕션 변경이 위 두 파일 밖으로 번져야 함 | FFIR-2 | 재가 상향 |
| 로컬 5회 연속 실행이 작전한계점(campaign 12항)에 걸림 | FFIR-3 | D-1 |

**결정지점** — campaign 10항 D-1·D-2·D-3 을 그대로 쓴다. 이 명령이 신설하는 결정지점은 없다.

**우발계획**

| 조건 | 행동 | 결심자 | 상향 |
|---|---|---|---|
| C-1: 스텁이 `/v2/holiday` 를 한 번도 못 받음 | 실행 인자로 지역·언어를 고정해 국가 선택을 결정화한다. 그래도 안 오면 gist 응답을 로그로 확인하고 즉시보고 | 실행자 | D-2 |
| C-2: `.accessibilityElement(children: .contain)` 이 식별자를 노출 못 함 | 식별자를 그리드 내부의 단일 뷰로 내리거나 `.accessibilityAddTraits` 를 함께 건다. 프로덕션 변경 라인이 늘면 즉시보고 | 실행자 | FFIR-2 |

---

## 4. 검증·자원

- **검증 사다리** — T-1 은 러너 프로세스 안의 순수 XCTest 로 서버를 URLSession 왕복 검증(`-only-testing:TodoCalendarAppE2E/StubHTTPServerTests`). T-2 프로덕션 변경은 `TodoCalendarApp`·`CalendarScenes` 스킴으로 회귀 확인. T-4 는 e2e 스킴 전체.
- **파일 추가 직후 `mise exec -- tuist generate --no-open`** — T-1·T-3·T-4 가 파일을 만든다. 그 뒤에 테스트를 돌린다.
- **실기 확인** — 5회 연속 실행 통과율과 1회 소요를 잰다 (campaign 작전한계점: 5/5, 3분 이내). 실 외부 캘린더 DB mtime 을 실행 전후로 비교한다.
- **모델 티어** — 부록 C. 병렬 슬롯·워크트리 없음. 외부 자원 없음.

---

## 5. 보고

- **즉시** — 위 즉시보고 조건 6건, 가정 A-1~A-4 붕괴, rules 갭. `report-immediate.md` 서식으로 이슈 봇 코멘트.
- **정기** — 태스크 완료마다 진행 파일 갱신 + 이슈 본문 미러 재조립.
- **유저 부재 시** — 우발계획 C-1·C-2 는 실행자가 결심하고 계속한다. D-1~D-3 발동 조건에 걸리면 중단하고 보고한다.
- **종결 조건** — 3-가 최종상태 5줄 충족 + 5회 연속 실행 통과 → PR 생성 + 종결보고.

---

## 부록 A. 태스크 상세

### Task 1: 스텁 HTTP 서버

**Files**
- Create: `TodoCalendarApp/E2E/Stub/StubHTTPServer.swift`
- Test: `TodoCalendarApp/E2E/Stub/StubHTTPServerTests.swift`

**Interfaces**
- Produces: `StubHTTPServer` — `register(path:json:)` / `start() throws -> Int` / `stop()` / `handledRequestPaths` / `unhandledRequestPaths`
- Consumes: 없음

**시그니처**

```swift
final class StubHTTPServer {
    func register(path: String, json: String)
    func start() throws -> Int          // 바인딩된 포트
    func stop()
    var handledRequestPaths: [String] { get }
    var unhandledRequestPaths: [String] { get }
}
```

**설계 제약**
- `Network` 프레임워크 `NWListener(using: .tcp, on: .any)` — 포트 0 바인딩으로 OS 가 할당한다 (campaign 12항: 고정 포트는 이 레포 DB 파일명 충돌과 같은 부류의 실패다). `start()` 는 `listener.port` 가 채워질 때까지 기다렸다가 그 값을 반환한다.
- 요청 파싱은 **요청 라인의 경로만** 본다 — `GET /v2/holiday?year=2026 HTTP/1.1` → `/v2/holiday`. 쿼리스트링은 무시한다 (연·로케일·국가코드가 실행 시점마다 달라 경로 매칭이 유일하게 안정적이다).
- 헤더 끝(`\r\n\r\n`)까지 수신을 누적한다 — 한 번의 `receive` 로 다 온다고 가정하지 않는다.
- 응답은 `HTTP/1.1 200 OK` + `Content-Type: application/json` + `Content-Length` + `Connection: close`. 미등록 경로는 `404 Not Found` + 빈 본문.
- 기록 배열은 리스너 큐에서 쓰이고 테스트 스레드에서 읽힌다 — 전용 직렬 큐로 감싸 읽기는 `sync` 로 스냅샷을 반환한다.
- `static func` 금지 (CLAUDE.md §1) — 전부 인스턴스 메서드.
- 주석은 비자명한 제약에만 (`.claude/rules/swift-style.md` §5) — 포트 0 바인딩 이유 정도.

**엣지 케이스**
- 등록 안 된 경로 → 404 + `unhandledRequestPaths` 에 기록, 테스트는 실패시키지 않는다 (유저 결심).
- 같은 경로 재등록 → 마지막 등록이 이긴다.
- `stop()` 두 번 호출 → 두 번째는 무시한다.

**테스트 케이스 이름**
- `test_whenRegisteredPathRequested_respondsRegisteredJSON`
- `test_whenPathHasQueryString_matchesByPathOnly`
- `test_whenUnregisteredPathRequested_responds404AndRecordsPath`

**Steps**
- [ ] Step 1: `StubHTTPServer` 를 작성한다 — 리스너 기동·포트 반환·요청 라인 파싱·라우트 매칭·응답 작성·기록.
- [ ] Step 2: `StubHTTPServerTests` 를 작성한다 — 위 3개 케이스를 `URLSession` 왕복으로 검증한다.
- [ ] Step 3: `mise exec -- tuist generate --no-open` 후 `-only-testing:TodoCalendarAppE2E/StubHTTPServerTests` 로 통과 확인. 이 왕복은 러너 프로세스 안에서만 도는 것이라 A-1(앱 프로세스 접속)은 여기서 안 드러난다 — A-1 실측 자리는 T-4 다.

---

### Task 2: 프로덕션 종단 — 식별자 카탈로그와 청정 상태

**Files**
- Create: `Presentations/Scenes/Sources/AccessibilityID.swift`
- Modify: `Presentations/CalendarScenes/Sources/Month/MonthView.swift`
- Modify: `TodoCalendarApp/Sources/AppDelegate.swift`
- Modify: `.claude/rules/presentations-rules.md`

**Interfaces**
- Produces: `AccessibilityID` 정본, `-uiTest` 청정 상태
- Consumes: `AppEnvironment.isUITestRun`(`TodoCalendarApp/Sources/AppEnvironment.swift:22-27`), `AppEnvironment.groupID`

**(a) 접근성 식별자 카탈로그**

식별자를 뷰에 리터럴로 박지 않는다. `Scenes` 에 정본을 세우고 앱과 e2e 가 같은 심볼을 본다.

```swift
public enum AccessibilityID {
    public enum CalendarScene {
        public static let monthGrid = "calendar.month.grid"
    }
}
```

- **배치가 `Scenes` 인 이유**: Presentation 모듈끼리 직접 import 가 금지라 모듈 간 공유 계약은 전부 `Scenes` 가 진다(CLAUDE.md §2·presentations-rules §7 — `Scenes+Calendar.swift` 류가 이미 화면 단위로 갈려 있다). 식별자는 화면을 가로지르는 공유 계약이므로 같은 자리다. `CalendarScenes` 는 이미 `Scenes` 에 의존한다(`Presentations/CalendarScenes/Project.swift:17-18`) — `MonthView.swift` 에 `import Scenes` 한 줄만 는다.
- **화면별 중첩 enum 인 이유**: e2e 작성자가 이 파일 하나를 열면 "어느 화면에 어떤 단언 대상이 있나"가 목차로 읽힌다. 값 규약은 `<scene>.<component>[.<detail>]` 소문자 점 구분.
- `Calendar` 가 아니라 `CalendarScene` 인 이유: `Foundation.Calendar` 와 이름이 겹친다.
- `static func` 금지(CLAUDE.md §1)의 대상이 아니다 — `static let` 상수 정본은 `.claude/rules/swift-style.md` §3 예외(전역 설정값 정본)다.
- **rules 등재**: `.claude/rules/presentations-rules.md` §7 의 `Scenes` 파일 표에 `Scenes/Sources/AccessibilityID.swift` 행을 더하고, "접근성 식별자는 `AccessibilityID` 에만 정의하고 뷰에 리터럴을 쓰지 않는다"를 한 줄 추가한다. 등재하지 않으면 다음 사람이 같은 리터럴을 또 흩뿌린다.

**(b) 월 그리드 등재·적용**

`MonthView.gridWeeksView()`(`MonthView.swift:148-162`)가 반환하는 `VStack` 에 `.accessibilityElement(children: .contain)` + `.accessibilityIdentifier(AccessibilityID.CalendarScene.monthGrid)` 를 건다.

- `emptyGridView()` 가 아니라 `gridWeeksView()` 인 이유: 식별자가 존재한다는 것이 "주 데이터까지 채워져 그려졌다"를 뜻하게 만든다. 뷰 루트에 걸면 데이터가 비어도 존재한다.
- `children: .contain` 인 이유: 컨테이너만 식별 가능하게 하고 접근성 트리는 그대로 둔다. `.combine`·`.ignore` 는 자식 요소를 없애 VoiceOver 동작까지 바꾼다.

**(c) 청정 상태**

`AppDelegate.application(_:didFinishLaunchingWithOptions:)`(`AppDelegate.swift:23-42`)에서 **`ApplicationRootBuilder()` 생성보다 앞에** 인스턴스 메서드 호출을 한 줄 넣는다.

```swift
func resetStateForUITestRun() { ... }   // AppDelegate 인스턴스 메서드
```

- 배치 이유: `ApplicationBase` 의 저장 프로퍼티(`userDefaultEnvironmentStorage`, `ApplicationBase.swift:30-32`)가 생성 시점에 초기화되므로, 그 뒤에 지우면 이미 읽힌 값이 살아 있다. AppDelegate 초입이 composition root 의 가장 앞이다.
- 지우는 것 둘: App Group 컨테이너의 `test_dummy` 접두 `.db` 파일 전부(`AppEnvironment.dbFilePath` 가 `test_dummy` 와 `test_dummy_<uid>` 두 형태를 만든다 — `AppEnvironment.swift:36-58`), 그리고 `UserDefaults(suiteName: AppEnvironment.groupID)` 의 persistent domain.
- 가드: `AppEnvironment.isUITestRun` 이 참일 때만. `isTestBuild`(유닛 테스트)에서는 돌지 않는다 — 유닛 테스트는 자기 DB 수명을 스스로 관리하고, 여기서 지우면 기존 스킴의 동작이 바뀐다.
- 삭제 대상이 실 DB(`models.db`)가 아님은 접두사로 보장된다.

**엣지 케이스**
- 컨테이너 URL 이 nil (App Group 미설정) → 조용히 넘어간다. e2e 실패로 드러나는 게 맞고, 여기서 크래시를 내면 일반 실행 위험이 생긴다.
- 파일이 없음 → 무시 (`try?`).

**테스트 케이스 이름** — 없음. 축1 선언은 생략 형식으로 남긴다: `.accessibilityIdentifier` 는 SwiftUI 뷰 수식어라 유닛 TC 가 붙을 자리가 없고(선례: 이 레포 Presentations 전체에 뷰 수식어 TC 없음), `resetStateForUITestRun` 은 `AppDelegate` 인스턴스 메서드인데 `TodoCalendarAppTests` 에 `AppDelegate` 를 다루는 TC 가 하나도 없다(전수 grep — 선례상 앱 델리게이트는 TC 대상이 아니다). 테스트 타겟이 앱 실행을 조립하지도 않는다(`ApplicationBase`·`ApplicationRootBuilder` 미생성 — DP-1.1 정찰에서 grep 확인). **대체 검증은 T-4 의 e2e 실행 자체다** — 식별자가 없으면 단언이 실패하고, 청정화가 안 되면 유니크 픽스처 이름이 안 떠 실패한다.

**Steps**
- [ ] Step 1: `Scenes` 에 `AccessibilityID` 정본을 만들고 presentations-rules §7 에 등재한다.
- [ ] Step 2: `MonthView.swift` 에 `import Scenes` 를 더하고 `gridWeeksView()` 에 카탈로그 심볼로 식별자를 건다.
- [ ] Step 3: `AppDelegate.resetStateForUITestRun()` 을 추가하고 `didFinishLaunchingWithOptions` 초입에서 호출한다.
- [ ] Step 4: 파일을 추가했으므로 `mise exec -- tuist generate --no-open` 후 `TodoCalendarApp`·`CalendarScenes`·`Scenes` 스킴으로 회귀 확인 (run-tests 스킬).

---

### Task 3: e2e 타겟 배선과 픽스처

**Files**
- Modify: `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`
- Create: `TodoCalendarApp/E2E/Fixtures/holidays.json`
- Create: `TodoCalendarApp/E2E/Fixtures/E2EFixture.swift`
- Test: `TodoCalendarApp/E2E/Fixtures/E2EFixtureTests.swift`

**Interfaces**
- Produces: `E2EFixture.holidaysJSON(named:on:) -> String`
- Consumes: 번들 리소스 `holidays.json`

**시그니처**

```swift
final class E2EFixture {
    func holidaysJSON(named name: String, on day: Date) -> String
}
```

`final class` 인 이유: 리소스 조회에 `Bundle(for: Self.self)` 가 필요하다 (struct 는 클래스 번들 조회를 못 쓴다).

**픽스처 본문** — `Repository/Sources/Repository+Imple/Calendar/HolidayRepositoryImple.swift:242-268` 의 디코딩 스키마를 그대로 따른다.

```json
{ "items": [ { "id": "e2e-holiday", "summary": "{{NAME}}", "start": { "date": "{{DATE}}" } } ] }
```

- `{{NAME}}`·`{{DATE}}` 를 로더가 치환한다. 날짜는 실행 시점의 오늘(`yyyy-MM-dd`) — 실 공휴일 유무와 무관하게 응답이 결정적이다. 이름은 시나리오가 매 실행 유니크하게 넘긴다.

**팩토리 배선** — `makeE2ETarget`(`Project+Templates.swift:144-160`)에 둘을 더한다.

1. `resources: []` → `resources: ["E2E/Fixtures/**"]`. `makeSnapshotsTarget`(`Project+Templates.swift:113` 부근)의 리소스 지정 방식이 동형 선례다.
2. `dependencies` 에 `.project(target: "Scenes", path: .relativeToRoot("Presentations/Scenes"))` 를 더해 e2e 가 `AccessibilityID` 를 심볼로 쓴다. `.relativeToRoot` 로 다른 프로젝트 타겟을 무는 것은 이 파일의 기존 패턴이다(`Project+Templates.swift:139-141`·`197-199`).

**엣지 케이스**
- 리소스 조회 실패 → `fatalError` 가 아니라 `XCTFail` 이 나도록 옵셔널을 반환하지 않고 빈 문자열로 뭉개지 않는다. 로더가 실패하면 그 자리에서 드러나야 한다 (`preconditionFailure` 로 러너를 세운다 — 러너 프로세스라 앱에 영향이 없다).

**테스트 케이스 이름**
- `test_holidaysJSON_replacesNameAndDatePlaceholders`

**Steps**
- [ ] Step 1: `makeE2ETarget` 에 리소스와 `Scenes` 의존을 배선한다.
- [ ] Step 2: `holidays.json` 과 `E2EFixture` 를 만든다.
- [ ] Step 3: `mise exec -- tuist generate --no-open` 후 `-only-testing:TodoCalendarAppE2E/E2EFixtureTests` 로 치환을 확인한다.

---

### Task 4: e2e 베이스와 콜드스타트 시나리오

**Files**
- Create: `TodoCalendarApp/E2E/E2ETestCase.swift`
- Modify: `TodoCalendarApp/E2E/AppLaunchE2ETests.swift`

**Interfaces**
- Consumes: `StubHTTPServer`, `E2EFixture`
- Produces: `E2ETestCase` — 하위 시나리오가 상속해 `stubServer`·`launchApp()` 를 얻는다

**시그니처**

```swift
class E2ETestCase: XCTestCase {
    private(set) var stubServer: StubHTTPServer!
    func launchApp() -> XCUIApplication      // -uiTest + E2E_API_HOST + 로케일 고정
}
```

**설계 제약**
- `setUp` 에서 서버를 띄우고 포트를 잡고, `tearDown` 에서 내린다 (유저 결심 — 다음 시나리오가 상속만으로 배선을 얻는다). campaign 12항이 "포트 0 바인딩 + tearDown 종료"를 과업으로 박았다.
- `launchApp()` 이 `launchArguments` 에 `-uiTest` 를, `launchEnvironment` 에 `E2E_API_HOST = "http://127.0.0.1:<port>"` 를 싣는다.
- 로케일·지역을 실행 인자로 고정한다 (A-3) — 지역 코드가 gist 목록과 매칭돼야 국가가 정해지고 홀리데이 요청이 나간다.
- `continueAfterFailure = false` 는 기존 파일(`AppLaunchE2ETests.swift:14-17`)의 관례를 베이스로 올린다.

**시나리오** — `AppLaunchE2ETests` 를 `E2ETestCase` 상속으로 바꾸고 단언을 둘로 세운다:
1. `app.otherElements[AccessibilityID.CalendarScene.monthGrid]` 가 뜬다 (타임아웃 30초 — 기존 값 유지).
2. `stubServer.handledRequestPaths` 에 `/v2/holiday` 가 1회 이상 있다.

공휴일 이름 텍스트는 단언하지 않는다 — 이벤트 라인 렌더가 행 높이·이벤트 스택 레이아웃에 물려 있어 실행 조건에 따라 점 마커로 대체될 수 있다. 픽스처가 앱까지 도달했는지는 단언 2 가 직접 증명한다.

**엣지 케이스**
- 스텁이 `/v2/holiday` 를 못 받음 → C-1.

**테스트 케이스 이름**
- `test_whenColdLaunchWithStubbedHolidays_calendarGridRendersFromStub`

**Steps**
- [ ] Step 1: `E2ETestCase` 를 만든다.
- [ ] Step 2: `AppLaunchE2ETests` 를 베이스 상속·2단언 시나리오로 다시 쓴다.
- [ ] Step 3: `mise exec -- tuist generate --no-open` 후 e2e 스킴 전체 실행. **A-1 이 여기서 실측된다** — 앱이 러너 서버에 못 붙으면 `handledRequestPaths` 가 비고, 그때 D-3 로 즉시보고하고 중단한다.
- [ ] Step 4: 실 외부 캘린더 DB mtime 을 실행 전후로 비교한다 — 변했으면 PIR-3 즉시보고.
- [ ] Step 5: 5회 연속 실행해 통과율·소요를 잰다. 5/5 가 아니거나 3분 초과면 D-1 즉시보고.

---

## 부록 B. 커밋 시퀀스

| 커밋 | 태스크 | 메시지 초안 |
|---|---|---|
| 1 | 계획 개정 + 이 명령 | `[#826] DP-1.2 작전명령 수립 — 프로덕션 개입 둘을 계획에 반영` |
| 2 | T-2 | `[#1057] 접근성 식별자 정본을 세우고 -uiTest 실행이 청정 상태로 시작한다` |
| 3 | T-1 + T-3 | `[#1057] 러너가 스텁 HTTP 서버로 홀리데이 픽스처를 공급한다` |
| 4 | T-4 | `[#1057] 콜드스타트 스모크가 그리드 렌더와 스텁 수신을 단언한다` |

프로덕션 변경(커밋 2)을 먼저 세워 리뷰어가 4항 코드 관점의 정량 상태를 한 커밋에서 셀 수 있게 한다.

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| T-1 | 표준 | HTTP 파싱·비동기 리스너 수명 관리 판단이 든다 |
| T-2 | 표준 | 카탈로그 구조·rules 등재 문안 판단이 든다 |
| T-3 | 하위 | 팩토리 두 줄 + 리소스 파일 + 치환 로더 |
| T-4 | 표준 | 베이스·시나리오 조율과 실측 판정이 든다 |

## 부록 D. 단편명령

없음.
