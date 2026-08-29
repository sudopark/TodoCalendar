---
name: analyze
description: Use when the user asks for a structured code analysis in this project — 로직 파악·실행 추적·객체 관계·영향도 분석을 code-analyzer subagent로 수행해 근거 있는 보고를 만든다. Triggers on "이 로직 분석해줘", "실행 흐름 추적해줘", "이거 고치면 어디까지 영향 가?". Does NOT trigger on 한두 파일 열어보면 끝나는 단순 질문(메인 세션이 직접 답), 킥오프 중 탐색(kickoff 스킬이 dispatch), PR 리뷰(review 스킬), 버그 원인 규명(superpowers systematic-debugging이 이끌고 필요 시 이 subagent를 부품으로 사용).
---

# Analyze — 코드 분석 수행

`code-analyzer` subagent(`.claude/agents/code-analyzer.md`)를 축·영역별 dispatch해 분석을 수행한다. 컨트롤러(이 세션)의 책임: 질문 확정 → 축 선정 → dispatch → 합산·보고.

## 1. 질문 확정

- 유저 요청을 **분석 목적 한 문장**으로 굳힌다. 대상(파일·심볼·기능)이나 알고 싶은 것이 모호하면 반문한다 — 모호한 채 dispatch하면 백과사전식 보고가 돌아온다.

## 2. 축 선정

질문 성격에 맞는 축(로직 파악 / 실행 추적 / 객체 관계 / 영향도)을 고른다. 대부분 1~2축이면 충분하다. 병렬 dispatch는 독립 영역일 때만 — 같은 영역에 여러 축이면 한 dispatch에 축을 묶는다.

## 3. Dispatch

dispatch마다 (Agent tool, `subagent_type: code-analyzer`) 프롬프트에 반드시:

- 분석 대상 — 시작점 file:line 또는 심볼
- 담당 축
- 분석 목적 (1에서 굳힌 문장)
- 보고가 길어질 규모면 산출 파일 경로(스크래치패드) — 컨트롤러 컨텍스트에 전문을 싣지 않는다
- **유저가 이 세션에서 지정한 제외·집중 조건** — subagent 기본 제외와 별개로 반드시 명시한다

모델: dispatch에 `model`을 지정하지 않는다 — agent frontmatter의 sonnet이 기본이다. 1차 보고의 "확인하지 못한 것"이 분석 목적의 답을 막고 있을 때만 `model: opus`로 재dispatch하고, 이미 확인된 사실(1차 보고 파일 경로)과 남은 질문을 함께 넘긴다.

## 4. 합산·보고

- 축별 보고를 **질문에 대한 답 구조로 재조립**한다 — subagent 보고 순서 그대로 나열 금지.
- 근거(file:line)를 유지한 채 요약한다. "확인하지 못한 것"은 합산에서도 살린다 — 숨기면 유저가 완전 분석으로 오독한다.
- 분석에서 파생된 수정·리팩토링은 이 스킬 밖 — 유저 지시가 있을 때 implement 스킬로.
