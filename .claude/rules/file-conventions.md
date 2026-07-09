---
description: 새 소스 파일 생성 시 전 레이어 공통 관례 — 파일 헤더 템플릿, import 순서
paths:
  - "Domain/**"
  - "Repository/**"
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
