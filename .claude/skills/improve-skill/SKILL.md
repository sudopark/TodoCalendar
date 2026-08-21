---
name: improve-skill
description: Use when running a maintenance cycle on a project skill or subagent — usage-log 레코드를 4분류로 진단해 스킬 md 개정안(diff)을 만들고 유저 승인 후 반영·소비 마킹한다. Triggers on "스킬 정비하자", "improve-skill 돌리자", "하네스 신호 기록해"(§5 누적 이슈 기록), pr 스킬 머지 단계의 임계 초과 제안을 유저가 수락했을 때. Does NOT trigger on 스킬 신규 작성(superpowers:writing-skills), 코드 리뷰 피드백 반영(feedback-reinforcement-learning), 유저가 지시한 일회성 스킬 문구 수정(직접 수정).
---

# Improve Skill — 스킬 정비 사이클

usage-log에 쌓인 신호(발동·skill_end·correction)를 근거로 대상 스킬을 진단하고 개정한다. **반영은 유저 승인 후에만** — 하네스는 모든 후속 작업에 곱해지는 레버리지라 무감독 self-modify 금지.

## 1. 레코드 수집

**누적 이슈에서 진입한 정비면 그 이슈 본문이 1차 입력이다** — §5가 쌓아둔 항목별 기여 레코드를 그대로 쓰고, 아래 스캔은 그 뒤에 새로 쌓인 레코드를 보태는 용도로만 돌린다. 이슈를 안 읽고 raw 스캔부터 하면 §5가 근거를 정리해둔 이유가 사라진다.

대상 스킬의 미소비 레코드(마지막 improvement 마킹 이후)를 모은다:

```bash
python3 - << 'EOF'
import json, glob, os
NAME = "<대상 스킬>"
records = []
for p in sorted(glob.glob(os.path.expanduser("~/.claude/usage-log/*.jsonl"))):
    try:
        with open(p, encoding="utf-8") as f:
            for l in f:
                try:
                    records.append(json.loads(l))
                except ValueError:
                    continue
    except OSError:
        continue
mark = max((r.get("ts", "") for r in records
            if r.get("event") == "improvement" and r.get("name") == NAME), default="")
for r in records:
    if r.get("ts", "") <= mark:
        continue
    if r.get("name") == NAME or NAME in (r.get("skills") or []) or r.get("skills") == []:
        print(json.dumps(r, ensure_ascii=False))
EOF
```

- `skills`가 빈 correction(미귀속)도 함께 나온다 — 발동 실패 후보로 검토하되, 응답 톤·글쓰기처럼 전역 규칙 소관이라 **의도적으로 비운 것**은 후보에서 뺀다 (CLAUDE.md §1 귀속 규칙). 미귀속에는 두 부류가 섞여 있고 레코드에 구분 필드가 없다.
- 서브에이전트(code-analyzer 등)를 정비할 땐 `event: agent` 레코드(name 매칭)와 dispatch한 스킬(analyze·review)의 레코드를 함께 조회.
- 필요하면 prompt 이벤트를 훑어 "스킬이 발동됐어야 했는데 안 된" 지시를 찾는다.

## 2. 4분류 진단

수집한 레코드를 분류하고, finding마다 근거 레코드(ts)를 붙여 표로 정리한다:

| 분류 | 판정 신호 | 처방 |
|---|---|---|
| **발동 실패** | 스킬이 떠야 했던 prompt에 skill 이벤트 없음 / 미귀속 correction | description Triggers/Does NOT 경계 수정 |
| **준수 실패** | skill_end partial 반복 — 특히 같은 clause | 조항 강조·위치 재배치 (조항이 안 읽히는 문제) |
| **설계 결함** | compliance full인데 correction 발생 | 조항 내용 자체 개정 |
| **과잉 조항** | 같은 clause 이탈 반복 + correction 없음 | 조항 삭제·완화 (YAGNI) |

## 3. 개정안

- 대상 스킬 md 원문을 읽고, 진단별 개정안을 **diff 형태**로 제시 — 무엇이 어떻게 바뀌고 왜(근거 레코드)인지.
- 스킬 작성 원칙은 superpowers:writing-skills를 따른다.

## 4. 승인·반영·마킹

- 유저가 승인한 항목만 반영. 프로젝트 스킬(`.claude/skills/`)은 커밋(개정 이력 = git), 글로벌(`~/.claude/skills/`)은 커밋 없이 수정.
- 반영 후 소비 마킹 — 같은 신호로 재발동되지 않게:

```bash
python3 .claude/hooks/log-record.py improvement --name <대상 스킬>
```

## 5. 누적 이슈 기록 — 유저가 "기록해" 라고 할 때

정비가 필요한 항목은 **열려 있는 누적 이슈 하나에 모은다.** 신호마다 이슈를 따로 따면 이슈가 불어나고 정비 단위가 잘게 쪼개진다.

1. 열린 누적 이슈를 찾는다 — `gh issue list --label harness --state open`. 없으면 새로 만든다 (`harness` 라벨, 제목에 누적 이슈임이 드러나게).
2. `triage-usage.py` 의 **actionable 항목만** 그 이슈에 더한다. 항목마다 셋을 넣는다:
   - `<!-- signal: <bucket>/<kind> -->` 마커 — 다음 런의 중복 판정 입력이다. 값은 추론하지 말고 `triage-usage.py` 출력의 `signal:` 줄을 그대로 옮긴다. **빠뜨리거나 틀리면 같은 신호가 계속 재보고된다.**
   - 기여 레코드(ts·요지) 목록 — 정비 시점에 근거를 다시 캐지 않게
   - 확정된 사실만. 처방이 이미 서면 적고, 안 섰으면 적지 않는다
3. 기존 이슈에 더할 땐 **본문을 편집한다** (`gh issue edit --body-file`). 코멘트로 쌓지 않는다 — 정비 시점에 한 번에 읽을 목록이라 본문에 있어야 한다.
4. **기록까지가 이 절차다.** 정비는 하지 않는다. 항목이 모이면 유저가 정비를 지시하고(§1~4), 완료 후 그 이슈를 닫는다.
