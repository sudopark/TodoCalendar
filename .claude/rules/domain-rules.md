---
description: Domain 레이어에서 모델·프로토콜·Usecase 작성 시 지킬 규칙
paths:
  - "Domain/**"
---

# Domain 레이어 규칙

Domain 모듈 내 파일을 수정하거나 생성할 때 아래 원칙을 따른다.

## 1. 모델 정의

- **`Decodable` / `Codable` 채택 금지.** Domain 모델은 순수 비즈니스 타입만 담는다. JSON 매핑은 Repository 레이어의 `XxxMapper` 타입(`Repository/Sources/Repository+Imple/**/Xxx+Mapping.swift`)에 분리. 기존 예: `TodoEventMapper`, `ForemostEventIdMapper`.
- **Optional 프로퍼티는 `var`로 선언**. 옵셔널은 "값이 없을 수 있다"는 의미이므로 변경 가능성을 열어두는 `var`가 자연스럽다 (struct에서도 동일).

## 2. 프로토콜 정의

### 기본 구현(default implementation) 주의
- protocol extension에 **default implementation을 함부로 추가하지 말 것.** 구현체와 중복을 유발한다.
- 모든 구현체가 동일하게 동작해야 하는 경우에만 default로 제공. 그 외에는 구현체 쪽 메서드로 둔다.
- 예: `DeviceInfoFetchService.fetchAppVersion()`의 default를 Domain 쪽에 `Bundle.main` 직접 참조로 넣으면, `DeviceInfoFetchServiceImple`이 이미 같은 로직을 가지고 있어 중복이 된다. → Domain 프로토콜은 메서드 시그니처만 선언하고, `Bundle.main` 참조 같은 구체 구현은 App 타겟 구현체에 둔다.
- Protocol-First 원칙상 "계약(인터페이스)만 선언하고, 구현은 별도 타입이 책임"이 기본값. default implementation은 예외적 수단.

## 3. Usecase 구현 스타일

- **Query / Command 분리**. 읽기(query)를 먼저 완성한 뒤 사이드이펙트(command)를 별도 실행. 한 흐름에 혼재 금지.
- **Higher-order functions 우선**. `map` / `flatMap` / `compactMap` / `forEach` 등 사용. imperative loop 지양.
- **`SharedDataStore.update` 안에서 외부로 값 흘려보내지 말 것.** `update` 클로저는 저장 전용. 외부 변수 캡처해서 appearance store 등 다른 곳에 넘기는 패턴 금지 — appearance store는 새로 들어온 값(incoming)만 받아 내부에서 merge 처리.

## 4. guard 탈출 블록

- `guard ... else { }`의 탈출 블록에 **로직을 많이 넣지 말 것**. 조기 탈출용이므로 가볍게 유지.
- `switch` case가 뚱뚱해지는 것도 비선호.
- 복잡한 분기는 별도 헬퍼 메서드로 추출하거나 로직 구조를 리팩토링해 탈출 블록이 단순하게 유지되도록 함. TDD의 리팩터 단계에서 정리.

## 5. 값 타입 업데이트는 Prelude/Optics 렌즈 연산자

struct 등 값 타입의 프로퍼티를 수정할 때 `var copy = origin; copy.x = y` 같은 수동 복사 대신 **Prelude/Optics 렌즈 연산자**로 불변 업데이트 체인을 구성한다.

```swift
// ✅ 선언적 체인
let updated = origin
    |> \.repeatingTimeToExcludes <>~ [currentTime.customKey]
    |> \.time .~ nextEventTime.time
    |> \.repeatingTurn .~ nextEventTime.turn

let event = TodoEvent()
    |> \.name .~ "new name"
    |> \.eventTagId .~ tagId

// SharedDataStore.update 안에서도 동일 패턴
sharedDataStore.update([String: TodoEvent].self, key: shareKey) {
    ($0 ?? [:]) |> key(event.uuid) .~ event
}

// ❌ 수동 복사 + mutation
var copy = origin
copy.time = nextEventTime.time
copy.repeatingTurn = nextEventTime.turn
let updated = copy
```

**연산자:**
- `|>` — apply (왼쪽 값을 오른쪽 변환에 흘려보냄)
- `.~` — set (프로퍼티 교체)
- `<>~` — concatenate (배열·Set 등 모노이드 구조에 append)
- `key(id) .~ value` — Dictionary 특정 키 업데이트

**Why:** 불변 데이터 흐름 유지. 여러 프로퍼티 업데이트를 한 선언적 체인으로 표현해 중간 변수·mutation을 제거하고 가독성을 높인다. 프로젝트 전반이 이 스타일로 작성돼 있어 일관성 유지에도 필요.

**How to apply:** 값 타입 프로퍼티 수정이 필요한 모든 곳(Usecase, Mapper, SharedDataStore.update 클로저 등)에서 이 패턴 사용. `Prelude`, `Optics` import를 잊지 말 것.
