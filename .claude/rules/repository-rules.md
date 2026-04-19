---
description: Repository 레이어(원격/로컬 구현)에서 지킬 규칙
paths:
  - "Repository/**"
  - "Domain/Sources/Repositories/**"
---

# Repository 레이어 규칙

Repository 프로토콜 또는 구현체를 수정·생성할 때 아래 원칙을 따른다.

## 1. 메서드 네이밍: fetch vs load

- **`fetch`** — 로컬 데이터 조회 전용 (SQLite, UserDefaults, Keychain 등)
- **`load`** — 원격(네트워크) 포함 조회. Remote API 호출이 수반되면 무조건 `load`.
- 예: `fetchTodoEvents()` (로컬 캐시) / `loadTodoEvents()` (원격 API + 로컬 반영)

## 2. JSON 디코딩 분리

- Domain 모델에 `Decodable` / `Codable` 채택을 **강요하지 말 것.** (Domain 규칙과 대응)
- Remote Repository 구현 시 JSON 디코딩은 별도 매퍼 타입으로 분리:
  ```
  Repository/Sources/Repository+Imple/**/Xxx+Mapping.swift
    struct XxxMapper: Decodable { ... }
  ```
  매퍼가 JSON을 받아 디코딩하고, 그 결과를 Domain 모델로 변환해 반환.
- 기존 참고: `TodoEventMapper`, `AppUpdateInfoMapper`, `ForemostEventIdMapper`.

## 3. 3-Layer 선택 (Local / Remote / UploadDecorator)

- 각 엔티티는 상황에 따라 3종 구현 중 적절한 것을 선택해 `ApplicationRootBuilder`에서 주입.
- 새 Repository 추가 시 기존 패턴(`TodoLocalRepositoryImple`, `TodoRemoteRepositoryImple`, `TodoUploadDecorateRepositoryImple`)을 먼저 확인.
- 세부: `Repository/CLAUDE.md`의 "3-Layer 패턴" 섹션 참조.
