---
name: add-file
description: Use when adding new source or test files to an existing framework in this project — 새 파일·새 Scene·새 테스트 추가 시점의 배치 경로 라우팅과 절차. Triggers on "파일 추가하자", "새 Scene 만들자", "새 Usecase/Repository 추가". Does NOT trigger on 신규 프레임워크(모듈) 신설(add-framework 스킬), 기존 파일 수정.
---

# Add File — 기존 프레임워크에 파일 추가

**규칙성 관례는 rules가 다룬다** — 파일 헤더·import 순서(`file-conventions.md`), 테스트 배치·네이밍(`testability.md` §8), Scene 폴더 조직(`presentations-rules.md` §3). path 매칭으로 자동 로드되니 이 스킬은 절차만 담당한다.

## 1. 배치 경로 결정 — 레이어별 라우팅

| 추가 대상 | 위치 | 세부 기준 |
|---|---|---|
| Domain 모델 | `Domain/Sources/Models/<서브도메인>/` | 서브도메인 분리 기준: `Domain/CLAUDE.md` |
| Usecase | `Domain/Sources/Usecases/<서브도메인>/` | bypass만 하면 typealias (`Domain/CLAUDE.md`) |
| Repository 프로토콜 | `Domain/Sources/Repositories/<서브도메인>/` | |
| Repository 구현 | `Repository/Sources/Repository+Imple/<서브도메인>/` | 3-Layer 패턴: `Repository/CLAUDE.md`. JSON 매핑은 같은 폴더 `Xxx+Mapping.swift` (repository-rules §2) |
| 새 Scene (6파일) | 해당 Scene 프레임워크 | 템플릿·생성 순서·체크리스트: `docs/scene-spec.md`. 폴더 위치: presentations-rules §3 |
| 공용 UI 컴포넌트 | `Presentations/CommonPresentation/Sources/` | 작성 전 인벤토리 확인 (presentations-rules §2) |
| 공유 Scene 프로토콜 | `Presentations/Scenes/Sources/Scenes+*.swift` | 모듈 간 직접 import 금지 (presentations-rules §7) |

## 2. 테스트 파일 동반

- `Tests/`에 Sources 미러 경로로 `XxxImpleTests.swift` (testability §8). 더블은 `Tests/Doubles/`.
- 테스트 프레임워크 선택(XCTest vs Swift Testing)·더블 네이밍은 testability §1·§2.

## 3. tuist generate

파일 추가/삭제/이동 **직후** `mise exec -- tuist generate --no-open`. 테스트·빌드는 반드시 generate 후 (implement 스킬 원칙과 동일).

## 4. 완료 판정

impact-check → 영향 스킴 테스트 → 짝 경고 해소는 implement 스킬이 규정한다 — 해당 시점에 함께 invoke한다.
