---
name: harness-review
description: Use when the user requests an agent review of pushed harness changes — 하네스 변경분(.claude 스킬·agents·rules·hooks, CLAUDE.md 계층, 지시문 정본 docs)이 포함된 공개 PR(또는 PR 없이 푸시된 하네스 커밋)에 대해 harness-reviewer subagent를 관점별 병렬 dispatch하고 결과를 합산·검증해 인라인 코멘트로 게시한다 — 게시할 앵커가 없으면 대화 보고로 갈음. Triggers on "하네스 리뷰 돌려", "스킬 수정분 리뷰해줘" (PR 또는 푸시된 커밋이 있는 상태에서). Does NOT trigger on 프로덕트 코드 리뷰(review 스킬), 스킬 신규 작성 중 검증(superpowers:writing-skills), usage-log 기반 정비(improve-skill), PR 올리기 전 셀프리뷰(수행하지 않음), PR 공개 시점 자동 실행(유저 지시가 유일한 트리거), 리뷰 반영 커밋 구성(commit 스킬), PR 본문 작성(pr 스킬).
---

# Harness Review — 하네스 수정분 에이전트 리뷰

`harness-reviewer` subagent(`.claude/agents/harness-reviewer.md`)를 관점별 병렬 dispatch해 하네스 변경분을 리뷰한다. 컨트롤러(이 세션)의 책임: 범위 확정 → 관점 선정 → dispatch → 합산·오탐 검증 → 결과 게시. 파이프라인 규약은 review 스킬과 같고, 대상 경로와 검사 기준만 하네스 전용이다.

## 0. 실행 시점

**유저가 지시했을 때만** 돈다 — 하네스 파일이 바뀌었다고 자동 실행하지 않고, PR 올리기 전 셀프리뷰도 없다.

대상은 **공개된 PR** 또는 **PR 없이 푸시된 하네스 커밋**이다. 후자는 대상이 develop 직행 커밋이거나, 유저가 게시 전 반영을 지시해 앵커 커밋이 rebase로 사라진 경우다 — §1~4는 동일하게 돌고 §5 인라인 게시만 대화 보고로 갈음한다. 이 경로는 이행이다.

## 1. 범위 확정 — 하네스 diff 패키지

- **먼저 `git fetch origin develop`** — 로컬이 stale이면 merge-base가 뒤로 밀려 남의 커밋이 섞인다. HEAD = 리뷰 대상 최신 커밋이고, BASE는 대상이 어디 있느냐로 갈린다:
  - **PR·미머지 브랜치** — `git merge-base origin/develop HEAD`. §0 후자 중 **앵커가 rebase로 사라진 경우**도 여기다 — 브랜치가 아직 develop에 안 들어가 공식이 그대로 성립한다
  - **develop 직행 커밋** — 대상 범위에서 가장 오래된 커밋의 부모(`<가장 오래된 커밋>^`). 대상이 이미 `origin/develop`의 조상이라 merge-base 공식은 HEAD로 수렴해 빈 패키지를 만든다
- **하네스 경로만** 필터해 스크래치패드에 diff 패키지를 만든다 (리뷰어들이 공유해 Read):

```bash
HARNESS_PATHS=(.claude CLAUDE.md Domain/CLAUDE.md Repository/CLAUDE.md scripts docs/coding-style-and-philosophy.md docs/화면단위구조.md docs/domain-context-map.md)
{ git log --oneline <BASE>..<HEAD> -- "${HARNESS_PATHS[@]}"; echo '---'; git diff --stat <BASE>..<HEAD> -- "${HARNESS_PATHS[@]}"; echo '---'; git diff -U10 <BASE>..<HEAD> -- "${HARNESS_PATHS[@]}"; } > <scratchpad>/harness-review-<PR번호 또는 커밋 SHA 앞7자>.diff
wc -l <scratchpad>/harness-review-<PR번호 또는 커밋 SHA 앞7자>.diff
```

경로 목록은 배열로 넘긴다 — 공백 구분 문자열을 `-- $VAR`로 풀면 기본 셸(zsh)에서 word split이 일어나지 않아 경로 하나로 붙고, git이 매치 0건을 내며 **빈 패키지가 조용히 만들어진다.** 줄 수를 찍어 확인하고, 변경이 있어야 하는데 비었으면 dispatch하지 말고 원인부터 잡는다.

- **혼합 PR이면 프로덕트 코드 부분은 review 스킬 소관** — 이 스킬은 하네스 파일만 본다. 둘 다 필요하면 각 스킬을 각자 지시로 돈다.

## 2. 관점 선정

diff 성격·규모에 맞춰 1~4개를 고른다 (고정 목록 아님 — diff에 맞게 재구성):

- **트리거·경계** — description 규격, 스킬 간 상호 배타(Does NOT trigger 짝), 발동 실패 위험
- **컨텍스트 예산·배치** — 줄 예산, 조항별 삭제 테스트, CLAUDE.md/rules/skill/hook 간 배치 적합성
- **정합·무모순** — 기존 하네스 전체와의 충돌·중복, dangling 참조, 짝 배선
- **집행 가능성** — 조항이 검증 가능한 구체 지시인가, hooks·스크립트 동작 정확성

작은 diff(파일 한둘·수십 줄)는 1~2관점으로 축소한다.

## 3. Dispatch

관점마다 harness-reviewer를 **병렬** dispatch (Agent tool, `subagent_type: harness-reviewer`). 각 프롬프트에 반드시:

- diff 패키지 파일 경로
- 담당 관점 서술 (한 문단)
- 개정 근거 소스 — 이슈·usage-log 진단·스펙 (있으면)
- **유저가 이 세션에서 지정한 제외·집중 조건**

모델: dispatch에 `model`을 지정하지 않는다 — agent frontmatter의 sonnet이 1차 기본이다. 승격은 review 스킬 §4 escalation을 따르되, "고위험 경로" 트리거는 하네스 대응으로 읽는다 — hook·스크립트 동작 변경, 스킬 간 조항 충돌 가능성이 있는 개편.

agent 타입이 세션에 미등록이면(신설·개명 직후) `subagent_type: harness-reviewer`가 거부된다 — general-purpose에 `.claude/agents/harness-reviewer.md`를 먼저 Read시켜 역할 주입으로 우회한다.

## 4. 합산·오탐 검증

review 스킬 §4를 그대로 따른다 — "코드"를 "문서"로 바꿔 읽는 것만 다르다. 절차를 여기 요약 복제하지 않는다 — 요약은 review §4 개정 시 조용히 stale해진다.

## 5. 결과 게시

review 스킬 §5와 동일 — `mcp__github-reviewer__create_pull_request_review`로 인라인 코멘트(full SHA), 게시 후 대화로 요약. 반영은 유저 지시 시 원본 커밋에 흡수. 축 누수 태깅(§6)은 수행하지 않는다 — 그건 프로덕트 코드 관문 채점용.

- **게시가 반영에 선행한다** — 지적을 원본 커밋에 흡수·rebase 하면 인라인 앵커가 사라진다. 반영은 게시 후 유저 지시로.
- **앵커가 없으면 대화 보고로 갈음한다** — PR 없는 대상, 또는 유저가 게시 전 반영을 지시한 경우. 확정 finding을 review 스킬 §4 보고 기준(인용·위치·reasoning)대로 대화에 실으면 게시 의무를 채운 것이다 (review §0 pre-PR 레인과 같은 규정).
