#!/bin/bash
# check-comments.py 회귀 테스트 — 임시 git 저장소에 fixture 커밋을 쌓아 검출·제외·실패 처리 검증
SCRIPT="$(cd "$(dirname "$0")" && pwd)/check-comments.py"
PASS=0; FAIL=0

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert_contains() { # desc substring text
  case "$3" in *"$2"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  missing: [$2]"; echo "  in: [$3]";; esac
}
assert_not_contains() { # desc substring text
  case "$3" in *"$2"*) FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  unexpected: [$2]"; echo "  in: [$3]";; *) PASS=$((PASS+1));; esac
}
assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fi
}

cd "$TMP_DIR" || exit 1
git init -q .
git config user.email t@t; git config user.name t
mkdir -p Sources Tests
echo "struct Base {}" > Sources/Base.swift
git add -A && git commit -qm base

# --- fixture: 검출 대상 + 제외 대상을 한 커밋에 섞는다 ---
cat > Sources/Detected.swift << 'SWIFT'
//
//  Detected.swift
//  Sources
//
//  Created by sudo.park on 1/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

struct Detected {
    // 세 줄짜리 서술 블록이다 여기서부터 설명이 길어지기 시작한다
    // 둘째 줄에서 앞의 내용을 부연하고 또 다른 근거를 덧붙인다
    // 셋째 줄까지 이어지며 판정 근거를 문단으로 풀어쓴다
    let three: Int

    // 두 줄짜리 서술 블록의 첫 줄이다 여기까지가 요지
    // 둘째 줄은 첫 줄에 대한 부연 설명을 덧붙인다
    let two: Int

    // 원래 다른 방식이었는데 이번에 바꿨다 — 작업 경위를 담은 한 줄
    let history: Int

    // 한 줄인데 예순 자 임계를 확실히 넘기도록 아주 장황하게 늘어놓은 설명 문장이라서 한 줄 장문으로 잡혀야 정상이다
    let long: Int

    // 짧은 한 줄
    let short: Int
}
SWIFT
cat > Sources/Excluded.swift << 'SWIFT'
// swiftlint:disable all
struct Excluded {
    // TODO: 나중에 처리한다 여기에 아주 긴 설명을 붙여도 마커라서 제외되어야 한다
    let todo: Int

    // MARK: - 섹션

    //        state.value = 1
    //        return state
    let commented: Int
}
SWIFT
cat > Tests/SomeTests.swift << 'SWIFT'
struct SomeTests {
    // 테스트 경로의 주석은 아무리 길고 장황하게 서술형으로 써도 대상에서 빠져야 한다
    let a: Int
}
SWIFT
git add -A && git commit -qm fixture
OUT=$(python3 "$SCRIPT" HEAD~1 HEAD 2>&1)

assert_contains "3줄 블록 검출" "3줄 블록" "$OUT"
assert_contains "2줄 블록 검출" "2줄 블록" "$OUT"
assert_contains "작업 경위 검출" "작업 경위 서술" "$OUT"
assert_contains "한 줄 장문 검출" "한 줄 장문" "$OUT"
assert_not_contains "짧은 한 줄은 미검출" "짧은 한 줄" "$OUT"
assert_not_contains "파일 헤더 제외" "Created by" "$OUT"
assert_not_contains "TODO 마커 제외" "TODO:" "$OUT"
assert_not_contains "swiftlint 지시어 제외" "swiftlint" "$OUT"
assert_not_contains "주석 처리된 코드 제외" "state.value" "$OUT"
assert_not_contains "Tests 경로 제외" "SomeTests" "$OUT"

# --- 공백 포함 경로 (git이 diff 헤더 끝에 탭을 붙인다) ---
cat > "Sources/My File.swift" << 'SWIFT'
struct MyFile {
    // 공백이 들어간 경로의 파일에 추가된 두 줄 블록의 첫 줄이다
    // 둘째 줄까지 이어져 블록으로 확실히 잡히게 만든다
    let a: Int
}
SWIFT
git add -A && git commit -qm "space path"
OUT=$(python3 "$SCRIPT" HEAD~1 HEAD 2>&1)
assert_contains "공백 포함 경로도 파싱" "My File.swift" "$OUT"

# --- 주석을 안 건드린 커밋 ---
echo "struct Plain { let a = 1 }" > Sources/Plain.swift
git add -A && git commit -qm plain
OUT=$(python3 "$SCRIPT" HEAD~1 HEAD 2>&1)
assert_contains "주석 없으면 대상 없음" "검토 대상 없음" "$OUT"

# --- 삭제만 있는 커밋 (주석을 지운 브랜치는 통과해야 한다) ---
git rm -q "Sources/My File.swift"
git commit -qm "delete only"
OUT=$(python3 "$SCRIPT" HEAD~1 HEAD 2>&1)
assert_contains "삭제만 있으면 대상 없음" "검토 대상 없음" "$OUT"

# --- 존재하지 않는 ref는 조용히 통과하지 않는다 ---
OUT=$(python3 "$SCRIPT" no-such-ref-xyz HEAD 2>&1)
CODE=$?
assert_eq "없는 ref는 non-zero 종료" "1" "$CODE"
assert_contains "없는 ref는 실패 사유 출력" "git diff 실패" "$OUT"
assert_not_contains "없는 ref를 0줄로 위장하지 않음" "검토 대상 없음" "$OUT"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
