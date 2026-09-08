# 작업 지침 (Operation Order) — M · DP

> 용어 — DP: 결정적 지점(작업 지침 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

작업 지침 — #1061 캠페인 상황판       초안: 에이전트   재가: 유저   일자: 2026-09-09
상위: 단독

■ 확인보고 — 임무 / 의도 / 자율로 정할 것 / 묻는 것

- 임무 (내 말로): 레포 밖 `~/.claude/campaign-board/` 에 상황판 앱(파서·로컬 서버·정적 렌더러)을 만들고, 이 레포엔 스풀 sync 스크립트와 campaign·opord 스킬 배선을 넣어, 진행 중인 캠페인의 노력선 × 단계 격자와 작업 지침 태스크 진행을 로컬 브라우저와 Artifact 원격 미러로 실시간 추적 가능하게 한다.
- 의도: 상태가 바뀌는 유일한 주체가 Claude 세션이므로, 세션이 미러를 재조립하는 그 자리에서 스풀 복사와 Artifact 재게시까지 함께 일어나게 한다. 최종상태는 아래 3-가.
- 자율로 정할 것: 화면의 색·타이포·레이아웃 세부, 파서 내부 구조, HTML/JS 구현 세부, 픽스처 내용.
- 묻는 것: 없음.

## 1. 상황

가. 정찰 결과 — 계획에 영향 주는 것만

- 격자의 데이터 정본은 campaign.md 9항 DP 목록 표다 (`docs/operations/templates/campaign.md:21` — | DP | LOE | 단계 | 내용 | 선행 DP | 소유 범위 | 사이즈 |). 8항 격자 표는 파생 문서라 파싱하지 않는다.
- 캠페인 원장 서식은 `docs/operations/templates/campaign.md:32` (18항) — | DP | 상태 미착수/착수/실행/검토/머지 | 이슈# | 브랜치 | base | PR# | 비고 | + 현재 국면 줄. 파일 경로는 `.operations/<상위이슈>/campaign-progress.md`.
- 작업 지침 진행 파일 서식은 opord 스킬 §8 — `<!-- progress -->` 헤딩 + `명령 상태:` 줄 + 태스크 표 | 태스크 | 상태 | 커밋 | 보고 |. 실물 예시는 `.operations/1044/progress.md`.
- 배선 앵커는 미러 재조립 조항이다 — campaign SKILL.md §5(원장·미러 재조립)와 opord SKILL.md §7(저장·미러). 미러 재조립 시점 목록이 이미 "상태 변화를 외부에 알릴 시점"의 정본이므로 새 시점 목록을 만들지 않는다.
- 하네스 셸 스크립트 테스트 관례는 `.claude/scripts/triage-usage.test.sh:1-20` — 같은 디렉토리에 `<이름>.test.sh`, mktemp 작업 디렉토리 + trap 정리 + assert 함수 + PASS/FAIL 카운트.
- `~/.claude/campaign-board/` 는 현재 없다 — 전부 신설이다.
- 설계 정본은 `docs/superpowers/specs/2026-09-09-campaign-board-design.md` (로컬 전용) — 이 지침과 어긋나면 이 지침이 우선한다.

나. 장애·마찰

- 유력한 양상: 신교리 템플릿(2026-09-08 개편)의 캠페인 실물이 아직 0건이라, 파서 픽스처가 템플릿 기반 합성물이다. 첫 실캠페인에서 표 서식 편차가 나올 수 있다.
- 가장 위험한 양상: 스킬 배선 문언이 실행 세션에서 안 밟혀 스풀이 갱신되지 않는 것 (이슈 미러 미이행 전례 있음 — 2026-09-09 개정으로 미러가 절차 스텝화된 것이 완화 장치다).

다. 상위 인용 (M)

- 목적: 진행 중 계획 작업의 상태를 상황판처럼 한눈에, 원격에서도 보이게 한다 (#1061 본문).
- 문제 정의: 계획·진행 정본이 파일·이슈 본문에 흩어져 있어 훑어보는 수단이 없다.
- 최종상태: 3-가 참조.
- 가정: 1-라 참조.
- 위임: 화면·구현 세부는 실행자 자율 (확인보고).
- 제한: 3-라 참조.

라. 가정

| ID | 가정 | 출처 | 깨지면 |
|---|---|---|---|
| A1 | 신교리 campaign.md 산출물의 9항·원장 표가 템플릿 서식과 일치한다 | 신규 — 실호출 0건이라 미실측 | 파서 graceful degradation 으로 흡수하고, 편차를 픽스처에 반영한다 (D-1) |
| A2 | 세션이 Artifact tool 로 고정 URL 재게시를 할 수 있다 | 이 세션에서 게시·재게시 실측 완료 | 원격 미러 항목만 보류하고 로컬 상황판으로 종결한다 (우발 1) |
| A3 | `~/.claude/` 에 파일 생성이 가능하다 | 이 세션에서 쓰기 실측 완료 | 성립하지 않으면 즉시보고 |

마. 인접 작업

- #1055 위젯 분리 작업이 다른 세션에서 develop 에 커밋을 올리고 있다. 소유 범위(`.claude/scripts/`·`.claude/skills/campaign|opord`·레포 밖)와 겹치지 않는다.
- campaign·opord 스킬 문언은 이 세션이 오늘 세 차례 고쳤다 — 배선 추가 시 최신 develop 기준으로 rebase 충돌 없이 얹는다.

## 2. 임무

이 작업은 상황판 앱·sync 스크립트·스킬 배선이 전부 동작할 때까지 캠페인 상황판을 구축하여, 진행 중인 캠페인 격자와 작업 지침 태스크 진행을 로컬·원격에서 실시간 열람 가능하게 한다.

## 3. 실시

가. 의도

- 목적: 계획 작업 상태를 훑는 비용을 "서버 하나 켜두기 + 링크 하나" 로 줄인다.
- 핵심과업: 하네스의 미러 재조립 시점과 스풀·Artifact 갱신이 한 자리에서 짝으로 일어나게 한다 (성립 조건: 배선 조항이 미러 정본 조항 안에 살아서, 미러를 밟으면 스풀을 안 밟을 수 없다).
- 최종상태:
  - 동작 — `python3 ~/.claude/campaign-board/server.py` 로 서버가 뜨고 브라우저가 자동으로 열리며, 스풀의 캠페인이 격자(DP 는 ID+이름 배지, 원장 상태 색)로, 작업 지침이 태스크 진행 카드로 보인다. 스풀 파일이 바뀌면 1초 내 화면이 갱신된다. `render.py` 출력 HTML 이 같은 화면의 정적 스냅샷으로 Artifact 고정 URL 에 게시돼 있다.
  - 코드 — 상황판 앱은 python3 stdlib 만 쓰고, 서버는 `127.0.0.1` 에만 바인드한다.
  - 구조 — 레포 안 변경은 `.claude/scripts/campaign-board-sync.sh`(+테스트)와 campaign·opord 스킬의 배선 문언뿐이다.
  - 검증 — 파서 unittest 전건 통과, sync 테스트 전건 통과, 실기 확인(4항 사다리) 완료.
  - 외부 — Artifact 최초 게시가 완료되고 URL 이 `~/.claude/campaign-board/artifact-url.txt` 에 기록돼 있다.

나. 개념

- 결정적 행동: 파서를 픽스처 기반 TDD 로 먼저 완성한다 — 파서 출력 JSON 이 서버·렌더러·화면 전부의 계약이라, 이게 서면 나머지는 그 소비자다.
- 여건 조성: 신교리 템플릿·실물 진행 파일(#1044)로 픽스처를 만든다. 구판(#721)도 픽스처에 넣어 graceful degradation 을 처음부터 계약에 포함한다.
- 대안 경로: Artifact 재게시가 막히면(A2 붕괴) 원격 미러를 부록 D 단편명령으로 보류하고 로컬 상황판만으로 종결한다.
- 단계: 앱(T-1~T-3) → 레포 반영(T-4~T-5) → 실기·게시(T-6). 앱이 완성돼야 sync 의 목적지가 검증 가능하다.

다. 과업

- T-1: parser.py 를 작성하여, 스풀의 campaign.md·campaign-progress.md·opord progress.md 를 화면 계약 JSON 으로 변환한다.
- T-2: server.py 와 index.html 을 작성하여, 스풀을 mtime 폴링·SSE 로 반영하는 로컬 상황판을 띄운다.
- T-3: render.py 를 작성하여, 같은 화면의 self-contained 정적 HTML 을 뽑는다.
- T-4: campaign-board-sync.sh 와 테스트를 작성하여, 레포의 계획·진행 파일을 스풀로 나른다.
- T-5: campaign·opord 스킬의 미러 정본 조항에 sync 호출·Artifact 재게시를 짝으로 배선한다.
- T-6: 실기 검증을 완료하고 Artifact 최초 게시·URL 기록으로 원격 미러를 개통한다.

(상세 부록 A)

라. 협조지시

- 개시 조건: 없음 — 즉시 착수 가능하다.
- 제한: 상황판 앱에 외부 의존성(pip 패키지·프레임워크)을 넣지 않는다 (설치 없는 개인 도구 유지). 서버는 `127.0.0.1` 외 바인드 금지 (무인증 서버의 노출 방지). 레포 안에서는 부록 A Files 에 적힌 경로 밖을 수정하지 않는다 (소유 범위 밖 변경은 인접 작업·리뷰 범위를 오염시킨다). 렌더 HTML 은 수십 KB 이내로 유지한다 (세션 첫 재게시 전 read 비용).
- 위임 범위: 화면 세부·파서 내부 구조·픽스처 내용은 실행자 자율이다. DP 표기(ID+이름)와 상태 5값 색 구분은 자율 대상이 아니다 (유저 확정 사항).
- 수용 위험: 신교리 캠페인 실물 0건 상태의 픽스처 합성 (A1) — 첫 실캠페인에서 파서 보수 가능성을 받아들인다.
- 즉시보고 조건: FFIR-1 — A2·A3 붕괴 (Artifact 재게시 불가 / `~/.claude` 쓰기 불가) → 결정지점 D-2.
- 결정지점:

| ID | 결정 | 판단 정보 | 시한(조건) | 미결 시 기본 행동 |
|---|---|---|---|---|
| D-1 | 실물 캠페인 서식이 픽스처와 다를 때 파서를 고칠지 서식을 고칠지 | 첫 실캠페인 파싱 결과 | 실캠페인 첫 등장 시 | 파서 graceful degradation 으로 표시하고 후속 이슈로 넘긴다 |
| D-2 | 원격 미러 보류 여부 | FFIR-1 | T-6 착수 시 | 로컬만으로 종결하고 원격 미러를 단편명령으로 보류한다 |

- 우발계획:

| 조건 | 행동 | 결심자 | 상향 |
|---|---|---|---|
| Artifact 재게시 실패 (A2) | D-2 기본 행동 | 실행자 | 종결보고에 기재 |
| 포트 8722 점유 | `--port` 옵션으로 회피하고 안내 문구를 확인한다 | 실행자 | 불요 |
| 배선 앵커 조항이 develop 에서 이동·삭제됨 | 최신 문언에서 동등한 미러 정본 조항을 찾아 배선하고, 못 찾으면 T-5 만 보류하고 즉시보고한다 | 실행자 | 즉시보고 |

## 4. 검증·자원

- 파서: `python3 -m unittest discover ~/.claude/campaign-board/tests` 전건 통과.
- sync: `bash .claude/scripts/campaign-board-sync.test.sh` 전건 통과 (기존 *.test.sh 관례).
- 실기 사다리: 픽스처 스풀로 서버 기동 → 브라우저에서 목록·격자·드릴다운·DP ID+이름 표기 육안 확인 → 픽스처 파일 수정 후 1초 내 SSE 갱신 확인 → render.py 출력 HTML 을 브라우저로 열어 동일 화면 확인 → Artifact 게시 후 모바일 브라우저 열람은 유저 확인.
- 자원: 인라인 실행 (이 세션). 테스트 스킴·시뮬레이터 불요 — iOS 코드를 건드리지 않는다.

## 5. 보고

- 즉시: FFIR-1 (3-라), 배선 대상 조항이 develop 에서 이동·삭제돼 앵커를 못 찾을 때.
- 정기: 태스크 완료마다 진행 파일 갱신 + 이슈 본문 미러.
- 유저 부재 시: 의도(3-가) 안이면 기본안으로 계속하고, A2·A3 붕괴면 해당 항목만 보류한 채 나머지를 완성한다.
- 종결 조건: 3-가 최종상태 전부 충족 + 레포 반영분 PR 생성.

## 부록 A. 태스크 상세

파서 출력 JSON 계약 (T-1 Produces, T-2·T-3 Consumes):

```
{ "campaigns": [ { "issue": "721", "title": "...", "phase_current": "...",
    "loes": [{"id": "LOE-1", "name": "..."}], "phases": ["1단계 ...", ...],
    "dps": [{"id": "DP-1.1", "name": "...", "loe": "LOE-1", "phase": "...", "size": "M",
             "prereq": [...], "own": "...", "status": "미착수|착수|실행|검토|머지",
             "issue_no": "...", "pr": "..."}],
    "parse_errors": ["..."] } ],
  "opords": [ { "issue": "1061", "title": "...", "state": "초안|재가|실행|종결",
    "tasks": [{"name": "Task 1", "status": "...", "commit": "...", "report": "..."}],
    "done_count": 2, "total_count": 5 } ] }
```

- 캠페인 소속 판정: 원장 이슈# 칸에 등장하는 이슈의 opord 는 그 DP 드릴다운으로 연결하고, 어느 원장에도 없는 opord 는 단독 M 섹션에 놓는다.
- 종결 판정: 캠페인은 전 DP status 가 `머지`, 작업 지침은 state 가 `종결`.

### Task 1: parser.py — 계획·진행 파일 파서

**Files**
- Create: `~/.claude/campaign-board/parser.py`, `~/.claude/campaign-board/tests/test_parser.py`, `~/.claude/campaign-board/tests/fixtures/` (신교리 캠페인 합성 1건 + `.operations/1044/progress.md` 사본 + 구판 `docs/operations/721/campaign.md` 발췌 + 깨진 표 1건)

**Interfaces**
- Produces: `parse_state(state_dir: Path) -> dict` — 위 JSON 계약. 마크다운 표 파싱은 `|` 구분 행을 셀로 쪼개는 수준이면 충분하다 (동형: `.claude/scripts/triage-usage.py` 의 단순 텍스트 파싱 스타일).

**Steps**
- [ ] Step 1: 픽스처 4종을 만든다 — 신교리 campaign.md(9항 좌표·이름 포함)+원장, opord progress.md, 구판 campaign.md, 표가 깨진 파일.
- [ ] Step 2: RED — 테스트를 먼저 쓴다: `test_parse_campaign_dp_list_with_names`, `test_parse_ledger_status_and_links`, `test_parse_opord_progress_tasks`, `test_grid_coords_from_section9`, `test_all_dp_merged_marks_campaign_closed`, `test_legacy_campaign_degrades_to_table_only`, `test_broken_table_reports_parse_error_not_crash`, `test_opord_without_ledger_entry_is_standalone`.
- [ ] Step 3: GREEN — parser.py 구현. 예외는 항목 단위로 잡아 `parse_errors` 에 담고 전체 파싱은 계속한다.

### Task 2: server.py + index.html — 로컬 상황판

**Files**
- Create: `~/.claude/campaign-board/server.py`, `~/.claude/campaign-board/index.html`

**Interfaces**
- Consumes: `parser.parse_state`.
- Produces: `GET /`(index.html), `GET /api/state`(JSON), `GET /events`(SSE). index.html 은 `/*__STATE__*/` 자리에 JSON 을 받아 그리는 단일 렌더 함수를 갖는다 — T-3 이 같은 파일을 재사용한다.

**Steps**
- [ ] Step 1: server.py — `http.server.ThreadingHTTPServer`, `127.0.0.1` 고정, `--port`(기본 8722)·`--no-open` 옵션, 기동 시 `state/` 생성 + macOS `open` 으로 브라우저 자동 열기, 스풀 mtime 1초 폴링 스레드가 변경 시 SSE 이벤트를 쏜다.
- [ ] Step 2: index.html — 목록(캠페인 카드·단독 M 섹션·종결 접기), 격자(노력선 행 × 단계 열, DP 배지 = `ID 이름` + 상태 색 5값, hover 에 전체 이름·소유 범위·PR 링크), DP 클릭 드릴다운(명령 상태 + 태스크 표 + 진행률), 우상단 SSE 연결 표시. 외부 리소스 없이 vanilla JS·CSS 인라인.
- [ ] Step 3: 픽스처 스풀로 실기 확인 (4항 사다리 앞 두 단).

### Task 3: render.py — 정적 스냅샷 렌더러

**Files**
- Create: `~/.claude/campaign-board/render.py`

**Interfaces**
- Consumes: `parser.parse_state`, index.html 템플릿.
- Produces: `render.py [--out <path>]` — `/*__STATE__*/` 에 JSON 을 인라인하고 SSE 코드를 끈 self-contained HTML (기본 출력 `~/.claude/campaign-board/board.html`).

**Steps**
- [ ] Step 1: index.html 의 상태 주입 자리를 치환해 정적 HTML 을 만들고, SSE 는 주입 플래그로 비활성화한다.
- [ ] Step 2: 출력 파일을 브라우저로 열어 서버 화면과 동일함을 육안 확인하고, 파일 크기가 수십 KB 이내인지 확인한다.

### Task 4: campaign-board-sync.sh + 테스트

**Files**
- Create: `.claude/scripts/campaign-board-sync.sh`, `.claude/scripts/campaign-board-sync.test.sh`

**Interfaces**
- Produces: `campaign-board-sync.sh <이슈번호>` — `docs/operations/<N>/campaign.md`·`opord*.md`, `.operations/<N>/campaign-progress.md`·`progress.md` 중 있는 것을 `~/.claude/campaign-board/state/<N>/` 로 복사한다. 스풀 루트 부재 시 무동작, 어떤 실패도 exit 0 (stderr 로만 남긴다). 스풀 루트는 `CAMPAIGN_BOARD_DIR` 환경변수로 재지정 가능 (테스트용 — 동형: `triage-usage.test.sh:8` 의 `USAGE_LOG_DIR`).

**Steps**
- [ ] Step 1: RED — 테스트 케이스: `spool_absent_noop_exit0`, `partial_files_copied`(계획만 있고 원장 없음), `all_files_copied`, `failure_still_exit0`(스풀 루트를 읽기 전용으로).
- [ ] Step 2: GREEN — 스크립트 구현. 관례는 `triage-usage.test.sh:1-20` 의 mktemp·trap·assert 구조를 따른다.

### Task 5: campaign·opord 스킬 배선

**Files**
- Modify: `.claude/skills/campaign/SKILL.md`, `.claude/skills/opord/SKILL.md`

**Interfaces**
- Consumes: T-4 스크립트, T-3 렌더러.

**Steps**
- [ ] Step 1: 미러 정본 조항(campaign §5 원장·미러 문단, opord §7 저장·미러)에 각 한 문장을 더한다 — "이슈 본문 미러를 재조립할 때마다 `.claude/scripts/campaign-board-sync.sh <이슈번호>` 를 함께 호출하고, `~/.claude/campaign-board/artifact-url.txt` 가 있으면 `render.py` 출력을 그 URL 로 Artifact 재게시한다 (둘 다 실패 비차단 — 절차를 막지 않는다)." 개별 호출 자리마다 반복하지 않는다 — 미러 조항이 정본이라 거기 한 번이면 전 시점을 덮는다.
- [ ] Step 2: 문언이 자연문 규칙(opord §1 공통 규칙)에 맞는지 소리 내 읽어 확인한다.

### Task 6: 실기 검증·원격 개통

**Files**
- Create: `~/.claude/campaign-board/artifact-url.txt`

**Steps**
- [ ] Step 1: 실캠페인이 없으므로 픽스처 스풀 + 실물 `.operations/1044`·`1045` 를 sync 로 밀어 넣고 4항 사다리를 전부 밟는다.
- [ ] Step 2: render.py 출력으로 Artifact 를 최초 게시하고 URL 을 artifact-url.txt 에 기록한다. 유저에게 링크를 전달한다.
- [ ] Step 3: 진행 파일·이슈 본문 미러를 갱신하고 커밋 시퀀스(부록 B)대로 PR 을 만든다.

## 부록 B. 커밋 시퀀스

레포 밖 산출물(상황판 앱)은 커밋 대상이 아니다. 레포 커밋은 둘이다:

1. `[#1061] 캠페인 상황판 스풀 sync 스크립트 추가 — 계획·진행 파일을 레포 밖 스풀로 나른다` = Task 4
2. `[#1061] campaign·opord 미러 조항에 상황판 스풀·Artifact 재게시를 짝으로 배선한다` = Task 5

## 부록 C. 태스크별 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| T-1 | 표준 (sonnet급) | 프로즈 서식에서 파서 계약을 도출한다 |
| T-2 | 표준 (sonnet급) | 서버·화면·SSE 멀티 파일 조율이다 |
| T-3 | 하위 (haiku급) | 템플릿 치환 수준의 기계적 작업이다 |
| T-4 | 하위 (haiku급) | 경로가 전부 확정된 복사 스크립트다 |
| T-5 | 표준 (sonnet급) | 조항 문언 통합 판단이 필요하다 |
| T-6 | 인라인 (이 세션) | 실기 확인과 Artifact 게시는 세션 권한이 필요하다 |

## 부록 D. 단편명령 누적

없음.
