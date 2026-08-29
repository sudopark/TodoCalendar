---
name: troubleshoot
description: Use when fixing a bug or logical contradiction in this project — 버그 수정 착수, 개발·리뷰 중 논리 모순 발견, QA·CS 리포트 대응 등 결함의 원인 규명과 수정 방향 결정이 걸린 모든 시점. superpowers:systematic-debugging을 대체하지 않는 컴패니언 — root cause 규명 절차는 그 스킬이 이끌고, 이 스킬은 프로젝트 종속 절차(트러블슈팅 아카이브 조회·기록, 수정 방향 판정 게이트, 대규모 결함 escape hatch)를 주입한다. Triggers on "버그 고치자", "이거 왜 이래", 테스트 실패·재현 리포트 대응 — systematic-debugging invoke 시 함께. Does NOT trigger on 원인·수정 방향이 이미 확정돼 반영만 남은 경우(implement만), 기능 추가·리팩토링(결함 아님).
---

# Troubleshoot — 결함 수정 컴패니언

**superpowers:systematic-debugging의 대체가 아니다.** 4-Phase 규명 절차는 그 스킬이 이끈다. 이 스킬은 세 지점에 게이트를 주입한다: 착수 전(아카이브 조회) · 규명 후(방향 판정) · 종료 시(아카이브 기록). 방향 확정 후 구현은 implement 스킬 + superpowers TDD 소관.

## ① 착수 — 아카이브 조회 (Phase 1 전)

`docs/troubleshooting/INDEX.md`를 증상 키워드로 grep. 히트하면 레코드를 읽고:

- **재발** → 기존 해결·패턴(`patterns/`)을 우선 후보로 규명 시작
- **non-issue 판정 이력** → 판정 근거가 여전히 성립하는지 확인 후 조기 종료 가능

히트 없으면 그냥 진행 — 조회는 grep 한 번이 전부, 시간 쓰지 않는다.

## ② 수정 방향 판정 게이트 — root cause 확정 후, 구현 전

systematic-debugging Phase 3(가설 검증)이 끝난 뒤, Phase 4(구현) 진입 전에 통과한다.

**후보 동등 나열 금지.** "A일 수도, B일 수도"로 열거하고 끝내지 않는다. 아래 기준으로 판정해 **하나를 선택하고 이유를 한 줄로 선언**한다:

- 수정 범위가 명확한가 — 범위가 명확할수록 사이드이펙트가 작다
- 다른 후보보다 단순한가
- **리트머스**: 이 수정이 들어가면 다른 후보들이 안고 있던 제약·한계·보완 패치 필요성이 자연 소멸하는가 — 소멸시키는 쪽이 근본 수정이다

(기준은 확장 목록 — 운영하며 추가한다)

### 전제 검증 — 패치 위 패치 금지

이번 수정이 **기존 패치(과거의 workaround·invalidate·guard·강제 refresh류)에 의존하거나 그 위에 얹는 구조면 STOP.** 얹기 전에 그 패치가 증상 패치였는지 판정한다. 증상 패치 신호:

- 같은 클래스의 버그가 이미 재발했다 (규명 중 "그 버그도 이 구간에선 똑같이 재현되겠는데" 류의 발견 포함)
- 같은 트리거·guard를 여러 자리에 심어야 효과가 유지된다

신호가 있으면 패치를 늘리지 말고 그 패치가 덮고 있던 원인으로 한 층 내려간다. 깨진 유리창 — 첫 증상 패치를 방치하면 다음 수정이 그 위에 쌓인다.

### escape hatch — 근본 수정이 광범위할 때

근본 수정이 많은 곳을 뜯어야 하면 **혼자 범위를 정하지 말고 유저에게 보고**한다. 두 경로를 정리해 제시하고 결정을 기다린다:

- **(a) 국소 임시방편** — 적용 범위·한계·재발 조건을 명시
- **(b) 점진적 근본 수정** — 레이어별 커밋·별도 이슈로 단계 분할한 경로

(a)로 결정되면 레코드 resolution을 `workaround`로 남기고 (b)를 후속 이슈로 예약한다 — 잃어버리지 않는 것이 불변 조건.

## ③ 종료 — 아카이브 기록 (매 건)

**규명이 끝난 모든 건**에 남긴다 — 세 종착 상태 전부가 기록 시점이다:

- **수정 완료** (`fixed`·`workaround`) — commit/pr 스킬 전이 직전 (skill_end와 같은 타이밍)
- **non-issue 판정** — 판정 확정 시점에
- **규명 완료·수정 보류** (`deferred`) — 유저가 수정을 보류시켰거나 별도 이슈로 이관해 이번에 diff가 안 나갈 때. 보류 확정 시점에

`deferred`를 이슈로만 남기고 넘어가지 않는다 — 이슈 본문은 INDEX의 증상 키워드 검색 대상 밖이라, 재발 시 ① 착수 조회에 안 걸려 같은 규명을 처음부터 다시 한다. 아카이브를 두는 목적이 그 건에 한해 무효가 된다. **후속 이슈 번호를 레코드 frontmatter `issue:`에 반드시 남긴다** — 이게 갱신 훅의 앵커다. 나중에 그 이슈로 수정이 들어갈 때 kickoff §2 탐색이 이 레코드를 grep으로 끌어올리고, implement 완료 판정 3이 `resolution`을 `fixed`로 갱신한다 (새 레코드를 만들지 않는다). `issue:`가 비면 이 경로가 끊겨 레코드가 영구히 `deferred`로 남는다.

1. `docs/troubleshooting/YYYY-MM-DD-<증상-slug>.md` 생성:

```markdown
---
issue: "#N"            # 없으면 생략. 단 deferred는 필수 — 갱신 훅의 앵커
subdomain: Event | Calendar | ExternalCalendar | Account | AIAgent | Notification | Billing | Settings | Support | Infra
symptoms: [증상 키워드, 에러 메시지 조각, ...]
resolution: fixed | workaround | deferred | non-issue
pattern: 패턴명         # patterns/ 승격분 있으면
---

# <증상 한 줄>

- **증상**:
- **근본 원인**:
- **해결**: <결정된 수정. workaround면 한계·재발 조건과 (b) 후속 이슈 번호. deferred면 확정된 수정 방향·보류 사유·후속 이슈 번호>
- **기각 방향**: <방향> — <기각 이유>   ← 한 줄씩. 꼬리물기 재발 방지용으로 이 항목만 예외적으로 기록한다
```

2. `INDEX.md`에 한 줄 추가: `- [YYYY-MM-DD 제목](파일.md) — 서브도메인 / resolution / 증상 키워드`
3. **패턴 승격**: 같은 근본 원인 구조의 레코드가 2건 이상 쌓이면 `patterns/<패턴명>.md`로 추출하고 레코드들의 `pattern:`에서 참조한다. 1건짜리를 선제 승격하지 않는다 (YAGNI).

## Red Flags — 이 생각이 들면 STOP

| 생각 | 실제 |
|---|---|
| "기존 invalidate/refresh가 걸려 있으니 트리거만 당기면 된다" | 기존 패치 위에 얹는 중 — 전제 검증부터 |
| "컷오프 전에 넣기 딱 맞는 크기다" | 크기·마감이 방향을 정하면 안 된다 — 광범위하면 escape hatch로 유저에게 |
| "같은 트리거를 관련 자리 전부에 심자" | 자리마다 심어야 유지되는 수정 = 증상 패치 신호 |
| "방안 A/B/C가 있다" (판정 없이 종료) | 기준 적용해 하나 선택 + 이유 선언 |
| "아카이브 기록은 나중에" | 기록 없는 종료는 종료가 아니다 — 매 건 |
| "이번엔 안 고치니 기록할 게 없다" | 기록 대상은 수정이 아니라 규명 결과다 — `deferred`로 남긴다 |
| "후속 이슈에 다 적었으니 됐다" | 이슈는 INDEX 증상 검색 밖 — 재발 시 규명을 처음부터 다시 한다 |

## 종료 기록 — skill_end

commit/pr 스킬 전이 시점에 `log-record.py skill_end` (명령·compliance 규칙은 CLAUDE.md §1). 동반 발동된 superpowers:systematic-debugging도 같은 시점에 별도 기록한다 — 자체 종료 조항이 없어 여기가 기록 주체다 (implement 스킬 §종료 기록과 동일 규칙).
