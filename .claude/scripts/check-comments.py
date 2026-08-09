#!/usr/bin/env python3
"""브랜치가 추가한 Swift 주석 중 불필요 후보를 잡아낸다 (#820).

    python3 .claude/scripts/check-comments.py [base] [head]

base 기본값은 develop, head 기본값은 HEAD. 종료코드는 항상 0 — 게이트가 아니라
검토 목록을 내는 도구다. 판정은 사람이 한다. 스크립트는 "이건 봐야 한다"까지만 좁힌다.
"""
import re
import subprocess
import sys
from collections import defaultdict

SKIP_PATH = ("/Tests/", "/Doubles/", "/Derived/", "/Template/")
# 주석 형태의 기능 코드 — 지우면 동작이 바뀐다
DIRECTIVE = re.compile(r"^//\s*(swiftlint|swiftformat|sourcery|periphery):")
# 주석 처리된 코드·작업 마커 — 이 스크립트의 대상이 아니다
CODEY = re.compile(
    r"^//\s{2,}\S|^//\s*[\}\)\]]|"
    r"^//\s*(let |var |return|case |func |if |else|guard |self\.|state\.|\.[a-z]|\|>|@|"
    r"public |private |struct |class |protocol )"
)
MARKER = re.compile(r"TODO|FIXME|TOOD|MARK")


def added_comment_lines(base: str, head: str) -> dict[str, list[tuple[int, str]]]:
    """diff에서 추가된 주석 라인을 (파일 → [(신규 라인번호, 내용)])로 모은다."""
    proc = subprocess.run(
        ["git", "diff", "-U0", f"{base}...{head}"], capture_output=True, text=True
    )
    # 실패를 "추가된 주석 0줄"로 흘리면 안 본 것과 통과한 것이 구분되지 않는다
    if proc.returncode != 0:
        sys.exit(f"git diff 실패 ({base}...{head}):\n{proc.stderr.strip()}")
    diff = proc.stdout
    out: dict[str, list[tuple[int, str]]] = defaultdict(list)
    path, lineno = None, 0
    for raw in diff.split("\n"):
        if raw.startswith("+++ b/"):
            # 경로에 공백이 있으면 git이 헤더 끝에 탭을 붙인다
            path = raw[6:].rstrip("\t")
            continue
        hunk = re.match(r"^@@ -\S+ \+(\d+)", raw)
        if hunk:
            lineno = int(hunk.group(1))
            continue
        if not raw.startswith("+") or raw.startswith("+++"):
            continue
        if path and path.endswith(".swift") and not any(s in f"/{path}" for s in SKIP_PATH):
            body = raw[1:].strip()
            if body.startswith("//"):
                out[path].append((lineno, body))
        lineno += 1
    return out


def flag(block: list[tuple[int, str]]) -> str | None:
    """주석 블록 하나를 보고 지적 사유를 돌려준다. 해당 없으면 None."""
    texts = [t for _, t in block]
    if any(MARKER.search(t) or DIRECTIVE.match(t) for t in texts):
        return None
    if any(CODEY.match(t) for t in texts):
        return None
    if len(block) >= 3:
        return f"{len(block)}줄 블록 — why는 한두 줄로 줄거나 이름·구조로 드러낼 것"
    joined = " ".join(texts)
    if len(block) == 2:
        return "2줄 블록 — 둘째 줄이 첫 줄의 부연이면 덜어낼 것"
    if re.search(r"원래|이전에|바꿨|옮겨|기존에는|였음|하던 것|리팩터", joined):
        return "작업 경위 서술 — 커밋 메시지·PR 본문 소관"
    if len(joined) >= 60:
        return "한 줄 장문 — 코드가 이미 말하는 부분이 없는지 볼 것"
    return None


def main() -> int:
    base = sys.argv[1] if len(sys.argv) > 1 else "develop"
    head = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
    findings, total = [], 0
    for path, lines in sorted(added_comment_lines(base, head).items()):
        block: list[tuple[int, str]] = []
        for n, text in lines + [(-1, "")]:
            if block and n == block[-1][0] + 1:
                block.append((n, text))
                continue
            if block:
                total += len(block)
                reason = flag(block)
                if reason:
                    findings.append((path, block, reason))
            block = [(n, text)] if n > 0 else []

    if not findings:
        print(f"주석 검토 대상 없음 (추가된 주석 {total}줄)")
        return 0

    flagged = sum(len(b) for _, b, _ in findings)
    print(f"검토 필요 {len(findings)}건 / {flagged}줄 (추가된 주석 {total}줄)\n")
    for path, block, reason in findings:
        print(f"{path}:{block[0][0]}  — {reason}")
        for _, text in block:
            print(f"    {text[:100]}")
        print()
    print("각 건을 지울지 남길지 판단하고, 남기는 건 그 이유를 유저에게 한 줄로 밝힌다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
