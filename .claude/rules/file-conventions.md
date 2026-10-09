---
description: 전 레이어 공통 관례 — 파일 헤더 템플릿, import 순서, 새 기능의 배치(기존 확장 vs 신설), extension 파일 배치
paths:
  - "Domain/**"
  - "Repository/**"
  - "Services/**"
  - "Presentations/**"
  - "TodoCalendarApp/**"
  - "Supports/**"
---

# 파일 공통 관례

## 1. 파일 헤더 템플릿

새 Swift 파일 상단 주석은 최신형(Copyright 포함)으로:

```swift
//
//  <FileName>.swift
//  <TargetName>
//
//  Created by sudo.park on <M/d/yy>.
//  Copyright © <yyyy> com.sudo.park. All rights reserved.
//
```

- 2번째 유의미 줄 = 파일명, 3번째 = 소속 타겟(프레임워크)명 (`Domain` / `Repository` / `SettingScene` 등). 테스트 파일도 동일 형식.
- 구형(2023년식, Copyright 없는 형식)이 코드베이스에 혼재하나 새 파일은 최신형으로. 기존 파일 헤더 일괄 수정 금지.

## 2. import 순서

표준 라이브러리 → 렌즈 → 하위 레이어 → 공유 인터페이스 → 공용 UI 순:

```swift
import Foundation   // 또는 UIKit / SwiftUI
import Combine
import Prelude
import Optics
import Domain
import Scenes
import CommonPresentation
```

필요한 것만 import — 위 순서에서 해당 없는 줄은 생략.

## 3. 새 기능의 배치 — 기존 확장이 기본값

새 능력은 **이미 그 책임을 가진 타입에 메서드·case·필드를 더해서** 넣는다. 같은 서브도메인·같은 데이터 소스·같은 소비자를 가진 기존 Usecase·Repository·Service·ViewModel 이 있으면 그 타입을 넓힌다. 새 타입·프로토콜·파일은 아래 셋 중 하나를 댈 수 있을 때만 만든다:

1. **직접 연결이 불가하다** — 기존 타입에 넣으면 의존 방향이 뒤집히거나(하위 레이어가 상위를 앎), 모듈 경계를 넘는다.
2. **소비자가 지금 둘 이상이다** — 추상은 두 번째 소비자가 생길 때 도입한다. 소비자가 하나뿐인 프로토콜·래퍼·중간층은 만들지 않는다.
3. **관심사가 실제로 독립이다** — 서브도메인이 다르거나(`docs/domain-context-map.md`), 세만틱이 다르다. 이벤트 성격의 신호(`PassthroughSubject` — 팝업 트리거)와 상태 성격의 값(`CurrentValueSubject` — 조회 가능한 현재 값)은 한 source 로 합치지 않는다.

신설 전에 두 가지를 먼저 확인한다:

- **값이 이미 흐르고 있나** — "이 시점에 값이 없다"면 새 상태·상태기계를 만들기 전에 그 값의 출처를 역추적한다. 대개 응답이나 기존 필드에 이미 있고, 소비자까지 안 오는 것뿐이다. 안 오는 이유가 타입의 표현력 부족이면(두 단계를 한 타입으로 방출) 상태가 아니라 타입을 모델링한다 — enum case 로 단계를 드러내면 소유는 기존 자리에 그대로 둔다.
- **경계를 현재 시그니처로 판정하지 않았나** — 레이어 배치는 지금 인터페이스 형태가 아니라 소비자가 어쩔 수 없이 지정해야 하는 최소 어휘(대개 "어느 것" 하나)로 판정한다. 나머지 값을 구현체가 스스로 만들 수 있으면 인터페이스를 좁힌다. OS·SDK 스펙에 묶인 타입(`Codable`, `ActivityAttributes` 등)은 그 요건을 지는 구현체 쪽에 둔다.

**Why:** 신설은 파일·프로토콜·Imple·테스트 더블·조립 코드를 한꺼번에 늘리고, 읽는 사람이 따라갈 간접층을 남긴다. 소비자 하나뿐인 추상은 리팩터 게이트의 Speculative Generality 에도 안 걸린다.

## 4. extension 배치 — 같은 파일 안 `// MARK: -` 가 기본값

extension 은 대상 타입의 파일, 또는 그 extension 을 쓰는 파일 안에 `// MARK: -` 블록으로 둔다. `Type+Xxx.swift` 별도 파일은 아래 셋 중 하나일 때만 만든다:

1. **다른 파일 둘 이상이 쓴다** — 범용이면 `Extensions` 모듈, 모듈 내부 공용이면 그 모듈의 공용 위치로 간다.
2. **룰이 분리를 규정한다** — `Xxx+Mapping.swift`(repository-rules §2), Scene 6파일(presentations-rules §3), `Scenes+*.swift`(presentations-rules §7).
3. **채택 타겟이 대상 타입과 다르다** — 앱 타겟이 ServiceInterfaces 프로토콜을 채택하는 extension 처럼 대상 타입 파일에 둘 수 없는 경우.

**Why:** 파일을 떼면 `private` 헬퍼가 `internal` 로 넓어지고(testability §3), 파일이 늘어 찾고 따라가는 비용만 커진다. 위 `+Mapping`·`Scenes+` 이름은 규정이 있어 뗀 선례라 일반 관례로 따라 하지 않는다.
