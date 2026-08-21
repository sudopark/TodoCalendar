---
name: review
description: Use when the user requests an agent code review of an open pull request in this project — 공개된 PR에 대해 code-reviewer subagent를 다관점 병렬 dispatch하고 결과를 합산·검증해 인라인 코멘트로 게시한다. Triggers on "리뷰 돌려보자", "리뷰해줘" (PR이 올라간 상태에서). Does NOT trigger on PR 올리기 전 셀프리뷰(수행하지 않음), PR 공개 시점의 자동 실행(유저 지시가 유일한 트리거), PR 직전 최종 whole-branch 리뷰(superpowers subagent-driven-development 소관), 하네스 변경분 리뷰(harness-review 스킬), 리뷰 반영 커밋 구성(commit 스킬), PR 본문 작성(pr 스킬).
---

# Review — 에이전트 리뷰 수행

`code-reviewer` subagent(`.claude/agents/code-reviewer.md`)를 관점별 병렬 dispatch해 변경분을 리뷰한다. 컨트롤러(이 세션)의 책임: 범위 확정 → 관점 선정 → dispatch → 합산·오탐 검증 → 결과 게시.

## 0. 실행 시점

**공개된 PR에 대해 유저가 지시했을 때만** 돈다. PR 올리기 전 셀프리뷰 없음, PR이 공개됐다고 자동 실행도 없음 — "리뷰 돌려보자" 같은 명시 지시가 유일한 트리거다.

## 1. 범위 확정 — diff 패키지

- **먼저 `git fetch origin develop`** (base가 develop이 아니면 해당 브랜치) — 로컬이 stale이면 merge-base가 뒤로 밀려 남의 커밋이 diff 패키지에 섞인다.
- BASE = 그 base 브랜치와의 merge-base (`git merge-base origin/develop HEAD`), HEAD = 리뷰 대상 최신 커밋.
- 스크래치패드에 diff 패키지 파일 하나를 만든다 (리뷰어들이 공유해 Read — 컨트롤러 컨텍스트에 diff를 싣지 않는다):

```bash
{ git log --oneline <BASE>..<HEAD>; echo '---'; git diff --stat <BASE>..<HEAD>; echo '---'; git diff -U10 <BASE>..<HEAD>; } > <scratchpad>/review-package-<이슈번호>.diff
```

- 바이너리(png 등)는 diff에서 자연 제외된다. 패키지가 수천 줄을 넘으면 관점별 관련 파일로 나눈 패키지를 따로 만든다.
- diff에 하네스 경로(harness-review 스킬 §1의 HARNESS_PATHS)가 섞여 있으면 해당 파일은 harness-review 스킬 소관 — 이 스킬의 패키지에서 제외한다. **제외 후 패키지가 비면 review를 중단하고 harness-review로 전환한다.**

### 선행 분석 — 컨트롤러 재량

diff가 크거나 파급이 넓은 변경(공유 컴포넌트·프로토콜/시그니처 변경·동시성)이면 관점 dispatch 전에 code-analyzer(`.claude/agents/code-analyzer.md`, `subagent_type: code-analyzer`)로 **영향도·객체 관계** 분석 패키지를 만든다:

- 산출 파일 `<scratchpad>/analysis-<이슈번호>.md` — 모든 관점 리뷰어가 공유해 Read (분석 전문은 컨트롤러 컨텍스트에 싣지 않는다)
- 분석 목적엔 diff 요약과 "이 변경의 diff 밖 파급 지도"를 담는다
- 작은 diff(단일 관심사·수백 줄 이하)는 생략 — 리뷰어가 직접 주변을 판다

## 2. 관점 선정

diff 성격·규모에 맞춰 관점 세트를 고른다. 기본 후보 (고정 목록 아님 — diff에 맞게 재구성):

- **로직 정확성** — 동작 변화가 요구사항 대비 올바른가, 엣지 케이스·상태 경합
- **컨벤션·rules 정합** — rules 조항, CLAUDE.md 짝지어진 두 위치, 그리고 **문서화되지 않고 코드에만 존재하는 관례**(형제 컴포넌트의 타입 형태·의존 주입 방식·네이밍). rules에 없다고 관례가 아닌 게 아니다 — 신규 타입·서비스·팩토리가 들어오면 형제를 연다
- **문서-실물 정합** — 스킬·docs·주석·커밋 메시지가 실물 코드와 일치하는가
- **테스트 적정성** — testability 규칙 준수, 커버리지 공백, 테스트가 실동작을 검증하는가

작은 diff(단일 관심사·수백 줄 이하)는 1~2관점으로 축소한다. 관점 경계의 겹침은 합산에서 정리되므로 과민하지 않아도 된다.

## 3. Dispatch

관점마다 code-reviewer를 **병렬** dispatch (Agent tool, `subagent_type: code-reviewer`). 각 프롬프트에 반드시:

- diff 패키지 파일 경로
- 담당 관점 서술 (한 문단)
- 요구사항 소스 경로 — 이슈 스펙 브리프·플랜 (있으면)
- **유저가 이 세션에서 지정한 제외·집중 조건** — subagent 기본 제외와 별개로, 유저 조건은 프롬프트에 반드시 명시한다
- 분석 패키지 파일 경로 (선행 분석을 돌린 경우)

모델: dispatch에 `model`을 지정하지 않는다 — agent frontmatter의 sonnet이 1차 기본이다. 승격은 §4 escalation 경로로만 한다. diff 크기·리스크를 보고 미리 올리지 않는다 — 사전 승격하면 escalation이 돌 자리가 사라지고, 모든 PR이 "리스크 높음"으로 읽힌다.

## 4. 합산·오탐 검증

- 관점 간 중복 finding을 병합하고 심각도를 보수적으로 재판정한다.
- **리뷰어 주장을 그대로 유저에게 전달하지 않는다** — 게시 후보 전 finding을 심각도 무관하게 컨트롤러가 해당 코드를 직접 확인해 확정한다. 확정 기준은 결함이면 "어떤 입력·경로에서 어떻게 잘못되는가"를 코드 근거로, 테스트·배선 공백이면 그 부재를 직접 확인(어느 경로가 어떤 TC로도 커버 안 되는지, 어느 짝이 편측인지 grep)한 결과로, 컨벤션·스타일 지적이면 위반한 조항·관례를 인용으로 재서술할 수 있는가다.
- **확정 못 한 finding은 게시도, 보고 나열도 하지 않는다** — "~일 수도 있음" 류 가설은 리뷰 결과에 존재하지 않아야 한다. 지적 수는 성과가 아니다 — 전 관점 "이상 없음"이 유효한 리뷰 결과다.
- 증상 라인 지적이면 근본 원인 지점까지 추적해 그곳을 지적한다 — 원인을 못 짚은 지적은 확정이 아니다. 근본 원인이 diff 밖 파일이면 diff 내 증상·호출 라인에 코멘트하되 본문에 원인 file:line을 명시한다.
- 보고는 finding별 코드 인용 + 위치 + reasoning + 트레이드오프 포함 — 유저가 반영 여부를 판단할 수 있는 정보량으로. 결론 한 줄 나열 금지.

### Escalation — opus 재dispatch

1차(sonnet) 결과가 아래 중 하나에 걸리면 **걸린 관점만** `model: opus`로 재dispatch한다. 전 관점 재실행 아니다.

- **미확정 잔여** — 컨트롤러 검증에서 확정도 기각도 못 한 finding이 남았다. 그 finding을 프롬프트에 명시하고 확정 또는 기각 중 하나로 닫으라고 요구한다.
- **고위험 경로의 무소득** — diff에 동시성·DB 마이그레이션(루트 CLAUDE.md §1 짝 규칙 대상)·인증/보안 경로·다모듈 시그니처 파급이 포함됐는데, **그 위험을 실제로 검사한 관점**(대개 로직 정확성·테스트 적정성)이 "이상 없음"으로 끝났다. sonnet이 조용히 통과시킨 경우를 잡는 자리다. 그 위험을 보지 않는 관점(문서-실물 정합 등)의 "이상 없음"은 트리거가 아니다 — 관점을 안 좁히면 리스크 카테고리가 흔한 PR마다 무관한 관점이 딸려 올라가 상시 승격으로 되돌아간다.

재dispatch 프롬프트에는 **1차에서 이미 확인된 사실**을 함께 넘긴다 — 확정된 finding, 기각한 것과 그 기각 근거, 리뷰어가 Read/Grep으로 확인한 지점. opus가 같은 확인을 반복하는 대신 확정된 사실 위에서 추론을 확장하게 하는 게 escalation의 목적이다. 관점만 다시 던지면 1차와 같은 깊이가 나온다.

escalation 결과도 위 확정 기준을 그대로 통과해야 게시된다 — opus가 냈다는 이유로 검증을 면제하지 않는다.

## 5. 결과 게시

- `mcp__github-reviewer__create_pull_request_review`(bot 계정)로 **해당 코드 라인에 인라인 코멘트** — 한 코멘트에 몰아쓰지 않는다. `commit_id`는 full SHA (short SHA는 422).
- 게시 후 대화로 요약 보고. 반영은 유저 지시 시 **원본 커밋에 흡수** 후 `--force-with-lease` (commit 스킬의 흡수 절차) — PR 공개 후라고 별도 커밋으로 남기지 않는다. 추적성은 리뷰 스레드 대댓글(무엇을 어떻게 고쳤는지 + 흡수한 커밋 sha)로 담보한다.

## 6. 누수 태깅 (#690 채점 4축)

게시 직후, 컨트롤러 검증을 통과한 finding마다 "축1~3 중 어디서 잡혔어야 했나"를 판정해 기록한다 (축 정의 정본은 implement 스킬 §채점 4축 좌표계):

```bash
python3 .claude/hooks/log-record.py axis_leak --missed-axis <1|2|3> --finding "<한 줄 요약>" --pr <PR번호>
```

- 판정 기준: 결함이 **TC가 명세를 못 담음**(누락 케이스·false positive test)이면 축1 / **TC가 있는데도 동작 오류가 통과**면 축2 / **구현 구조·효율·역할 분배**면 축3.
- 축1~3 어디서도 잡을 수 없는 종류(기획 홀·요구사항 자체의 결함)는 태깅하지 않는다 — 관문 누수가 아니다.
- 집계·임계 판정은 aggregate-usage.py가 축별로 수행하고, 오탐·중복 판정은 triage-usage.py가 이어받아 pr 스킬 머지 단계에서 출력된다 — actionable로 남은 축은 누적 이슈에 항목으로 쌓이고(improve-skill §5), 정비 반영 후 소비 마킹은 `improvement --name axis:<n>`.
