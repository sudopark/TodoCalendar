---
description: 전 레이어 공통 Swift 스타일 — static 상수·메서드 배치 규칙, 클로저 캡처 규칙, 주석 규범
paths:
  - "Domain/**"
  - "Repository/**"
  - "Services/**"
  - "Presentations/**"
  - "TodoCalendarApp/**"
  - "Supports/**"
---

# Swift 공통 스타일 규칙

## 1. static 상수 — `private enum Constant`로 응집

타입 본문에 `static let` 상수를 흩뿌리지 않는다. 매직 넘버·설정값은 해당 타입 곁의 `private enum Constant`에 모은다:

```swift
private enum Constant {
    static let suggestionDays: Int = 30
    static let suggestionLimit: Int = 5
}
```

- 한 곳에서만 쓰는 값은 함수 내 로컬 상수(`let`)로 충분하면 그걸 우선.

## 2. static 메서드 — 인스턴스 소속 우선

로직은 인스턴스 소속으로 배치한다: 대상 타입 extension의 계산 프로퍼티·메서드, 또는 전용 struct(Mapper 등)의 인스턴스 메서드. 클래스·struct 본문의 `static func`는 지양.

- **허용 — 네임스페이스 enum 패턴**: case 없는 enum에 관련 유틸을 모으는 형태(`enum DDayTargetDateFormatter { static func ... }`)는 인스턴스화 자체가 불가능한 순수 네임스페이스라 허용.

## 3. static 규칙의 예외

- 전역 설정값 정본: `AppEnvironment`, Tuist `Project.appVersion` 등
- 프로토콜·프레임워크 요구사항: `static let title: LocalizedStringResource`(AppIntents)처럼 API가 static을 요구하는 경우

## 4. 클로저 캡처 — 사전 `let` 대신 캡처 리스트

클로저 본문이 `self`가 아니라 **`self`가 들고 있는 객체만** 쓰면, 사전 `let`으로 꺼내지 말고 캡처 리스트에 적는다. 두 형태는 동치이고(`[foo]`는 `[foo = self.foo]`의 sugar) 캡처 의도가 선언부에 드러난다.

```swift
// ❌
let repository = self.repository
self.someFunction { repository.load() }

// ✅
self.someFunction { [repository] in repository.load() }
```

- **`[weak self]`의 대체가 아니다.** `self`의 생사가 실행 여부를 결정해야 하면(화면 해제 후 돌면 안 되는 UI 갱신 등) `[weak self]`를 쓴다. `[foo]`는 생성 시점 값을 잡고 `self` 해제 후에도 실행되며, `self.foo` 재할당을 반영하지 않는다.
- **`[foo]`는 `foo`를 강하게 잡는다.** 그 클로저를 `foo` 자신이 보관하면(`self.node.onTick = { [node] in ... }`) `foo → 클로저 → foo` 새 사이클이 생긴다 — 이 자리엔 `[weak foo]`.

세만틱 대조표는 [`docs/coding-style-and-philosophy.md` §2.5](../../docs/coding-style-and-philosophy.md).

## 5. 주석 — 안 다는 게 기본

**주석을 새로 달려는 순간, 먼저 이름과 구조로 드러낼 수 없는지 의심한다.** 설명이 필요한 코드보다 설명이 필요 없는 코드가 낫다.

### 달지 말 것

- **다줄 서술** — 계약·상태 전이·판정 근거를 문단으로 풀어쓰기. 2줄을 넘으면 거의 항상 과하다.
- **작업 경위·히스토리** — "원래 X였는데", "어디서 옮겨옴", 이전 구현과의 비교. 커밋 메시지·PR 본문 소관이다.
- **이름 재서술** — `// 이벤트 생성자` 위의 `var creator`, `// 상대 말풍선 공통 컨테이너` 위의 `assistantBubble(_:)`.
- **코드 그대로 풀어쓰기** — `// 휘도가 0.5보다 크면 밝은 색` 위의 `return luminance > 0.5`.
- **미채택 대안·구상 메모** — "서버가 기능 키 배열을 주게 되면 이렇게 바뀐다" 류.

### 달아도 되는 경우

읽어서는 파악이 안 되는 **비자명한 제약**일 때만, *why*를 **한두 줄로**:

- 플랫폼 동작 (`PHPicker는 별도 프로세스라 앱이 라이브러리 권한을 갖지 않는다`)
- 순서 의존 (`accessory 케이스를 포괄 .success보다 앞에 둔다 — 뒤에 두면 소형 뷰가 잠금화면에 나온다`)
- fail-closed 같은 의도적 선택, 매직넘버 근거 (`calshow: scheme uses seconds since 2001-01-01`)

### 검증

PR 올리기 전 `python3 .claude/scripts/check-comments.py`로 이번 브랜치가 추가한 주석을 훑는다 (pr 스킬 소관). 지적된 건은 기본이 삭제다.

배경: #820 — AI 작업으로 유입된 서술형 주석 354줄을 사후 일괄 정리했다.
