# CLAUDE.md

## 1. 절대 규칙

- **수정 전 파일 먼저 read.** 추측 수정 금지.
- **Query/Command 분리.** 읽기와 사이드이펙트를 한 흐름에 섞지 말 것.
- **객체 변경 시** 참조하는 다른 객체 영향도 확인 (빌드 + 테스트) — 절차는 implement 스킬의 impact-check가 기계화.
- **짝지어진 두 위치는 함께 갱신.** 한쪽만 바꾸면 무효가 되는 쌍은 추가/변경 시 대응처도 반드시 확인:
  - `AppEnvironment.dbVersion` ↔ `Table.migrateStatement(for:)` case
  - CI `pr_test.yml` — `detect-changes`의 scheme 매핑(grep) ↔ `test` job의 `Test <scheme>` 실행 step (둘 중 하나만 추가하면 감지만 되고 실행 안 됨)
  - 신규 테스트 스킴 ↔ 스킴 목록 하드코딩 전부 (`pr_test.yml` 3곳·`scripts/run-all-tests.sh`·`impact-check.sh`+테스트·`run-tests` 스킬 — 상세는 add-framework 스킬. 단 `<Name>Snapshots` 스킴은 의도된 예외 — 로컬 전용, snapshot-check 스킬)
  - init 시그니처 ↔ 콜사이트
- **스킬 종료·유저 교정은 레코드로 남긴다** (#690 flywheel 측정 신호):
  - 발동한 스킬의 절차가 끝나면: `python3 .claude/hooks/log-record.py skill_end --name <스킬> --compliance full|partial [--deviation "조항::사유"]` — 조항을 의도적으로 이행 안 했으면 partial + 이탈 조항·사유 필수.
  - 유저가 작업 결과·방식을 교정하면 그 자리에서: `python3 .claude/hooks/log-record.py correction --skills <귀속 스킬(쉼표 구분)> --summary "교정 요지" --gist "발화 요지"` — 발동 중이던 스킬이 없으면 `--skills` 생략.
- **`.claude/rules/*.md`는 path 매칭 시 자동 로드** — 로드된 조항을 구현 결정 시점에 적극 invoke.
- **외운 지식 말고 이 문서를 보고 판단할 것.** (도메인 경계·용어는 [`docs/domain-context-map.md`](docs/domain-context-map.md) 정본 기준)

---

## 2. 아키텍처

### 의존성 방향

```
TodoCalendarApp → Presentations → Scenes / CommonPresentation → Domain ← Repository
```

Presentation 모듈끼리 직접 import 금지. `Scenes` 프레임워크의 공유 프로토콜로만 참조.

### 주요 파일

| 파일 | 역할 |
|---|---|
| `TodoCalendarApp/Sources/AppEnvironment.swift` | DB version, App Group ID, 외부 캘린더 서비스 목록 |
| `TodoCalendarApp/Sources/Root/ApplicationRootBuilder.swift` | 앱 시작 시 모든 Repository/Usecase/Factory 조립 |
| `TodoCalendarApp/Sources/Factories/ApplicationBase.swift` | Pool/Factory 인스턴스 생성 (다중 계정 인프라 포함) |
| `Tuist/ProjectDescriptionHelpers/Project+Templates.swift` | `Project.app()` / `Project.framework()` 팩토리 헬퍼 |

---

## 3. 워크플로우 — 상황별 하네스

```bash
./install/install.sh          # 더미 config 복사 (최초 1회)
tuist install                 # SPM 의존성 resolve
tuist generate --no-open      # 파일 추가/삭제 후 재실행 필수
```

상황이 오면 대응 하네스를 invoke한다 (스킬 자동 트리거의 보강 인덱스):

| 상황 | 하네스 |
|---|---|
| 이슈 기반 작업 착수 | kickoff 스킬 |
| 페어 프로그래밍 선언 | pair-programming 스킬 |
| 방향 수렴 선언 | converge 스킬 |
| 구현 계획 작성 | plan 스킬 (superpowers writing-plans 컴패니언) |
| 코드 작성·수정 | implement 스킬 (superpowers 코딩 절차 컴패니언) |
| 파일·프레임워크 추가 | add-file / add-framework 스킬 |
| 테스트 실행 | run-tests 스킬 (스킴 목록 정본) |
| UI 디자인 | design 스킬 |
| 스냅샷 검증·화면 카탈로그 | snapshot-check / app-catalog 스킬 |
| 코드 분석 (로직·추적·관계·영향도) | analyze 스킬 → code-analyzer subagent |
| 커밋 / PR / 이슈 | commit / pr / issue 스킬 |
| 공개 PR 에이전트 리뷰 | review 스킬 → code-reviewer subagent |

> 테스트 작성 원칙: [`.claude/rules/testability.md`](.claude/rules/testability.md) (path 매칭 자동 로드)

---

## 4. 도메인 컨텍스트

> **전략 지도 (DDD) — 대화·작업의 공통 언어 베이스.** 단일 도메인 + 8개 서브도메인. 경계·용어는 여기 맞춘다. 정본·오해나는용어집: [`docs/domain-context-map.md`](docs/domain-context-map.md).
>
> 🟥 Core: **Event**(Todo/Schedule·반복·완료·태깅·강조), **Calendar**(시간프레임·공휴일) · 🟧 Supporting: **External Calendar**(Google/Apple 다중계정), **Account/Auth**, **AI Agent**(command→Event 변경, Core 승격 유력), **Notification** · 🟩 Generic: **Settings**, **Support**(업데이트·피드백·STT 등)

세부 도메인 규칙은 CLAUDE.md에 중복하지 않는다. 각 정본을 읽고 판단할 것 (`Domain/CLAUDE.md`·`Repository/CLAUDE.md`는 해당 경로 작업 시 자동 로드):

| 주제 | 정본 |
|---|---|
| 이벤트 모델·EventTime·완료 | [`docs/spec/todo-event.md`](docs/spec/todo-event.md), [`schedule-event.md`](docs/spec/schedule-event.md) |
| 반복 이벤트·turn 규칙·수정 범위 | [`docs/spec/repeating-events.md`](docs/spec/repeating-events.md) |
| 이벤트 태그·색상·보이기숨기기 | [`Domain/CLAUDE.md`](Domain/CLAUDE.md), [`docs/spec/tags-foremost-notifications.md`](docs/spec/tags-foremost-notifications.md) |
| 외부 캘린더 다중 계정·Pool | [`Domain/CLAUDE.md`](Domain/CLAUDE.md), [`Repository/CLAUDE.md`](Repository/CLAUDE.md), [`docs/spec/google-calendar.md`](docs/spec/google-calendar.md) |
| ForemostEvent | [`docs/spec/tags-foremost-notifications.md`](docs/spec/tags-foremost-notifications.md) |
| SharedDataStore 키·구독 | [`Domain/CLAUDE.md`](Domain/CLAUDE.md) |
| 앱 버전 체크 | [`docs/spec/infrastructure.md §7`](docs/spec/infrastructure.md) |
| DB 마이그레이션 | §1 짝규칙 (`dbVersion` ↔ `migrateStatement`) + [`Repository/CLAUDE.md`](Repository/CLAUDE.md) |

---

## 5. 코딩 컨벤션

상세: [`docs/coding-style-and-philosophy.md`](docs/coding-style-and-philosophy.md)

### 네이밍

| 개념 | 패턴 |
|---|---|
| ViewModel | `XXXViewModel` (proto) / `XXXViewModelImple` |
| Router | `XXXRouting` (proto) / `XXXRouter` |
| Builder | `XXXSceneBuilder` (proto) / `XXXBuilderImple` |
| SwiftUI | `XXXViewState` / `XXXViewEventHandler` |
| Usecase | `XXXUsecase` (proto) / `XXXUsecaseImple` |
| Repository | `XXXRepository` (Domain) / `XXXLocalRepositoryImple` / `XXXRemoteRepositoryImple` |

### 커밋 메시지

`[#이슈번호] 동작 변화 요약`. 파일/클래스 목록 ❌ → 동작이 어떻게 달라졌나 ✅.

```
❌ [#563] AppleCalendarOAuth2ServiceUsecaseImple 로직 변경 및 테스트 추가
✅ [#563] AppleCalendar 권한 상태별 분기 체크 도입
   — fullAccess → 바로 성공, denied/restricted → 즉시 throw, notDetermined → 시스템 요청 후 재확인
```

---

## 6. Scene 스펙

- 상세 스펙(6파일, 생성 순서, SwiftUI 템플릿, Scene 간 통신): [`docs/scene-spec.md`](docs/scene-spec.md)
- MUST/MUST NOT 규칙: [`.claude/rules/presentations-rules.md`](.claude/rules/presentations-rules.md)
