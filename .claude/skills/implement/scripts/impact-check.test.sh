#!/bin/bash
# impact-check.sh stdin 모드 회귀 테스트
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0

schemes_for() {
  printf '%b\n' "$1" | bash impact-check.sh --stdin | awk '/^## 테스트 스킴/{getline; print; exit}'
}
tuist_for() {
  printf '%b\n' "$1" | bash impact-check.sh --stdin | awk '/^## tuist generate/{getline; print; exit}'
}
pairs_for() {
  printf '%b\n' "$1" | bash impact-check.sh --stdin | awk '/^## 짝지어진 두 위치/{flag=1; next} /^## /{flag=0} flag'
}

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fi
}
assert_contains() { # desc pattern actual
  if printf '%s' "$3" | grep -q "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  pattern [$2] not in: [$3]"; fi
}

# --- 테스트 스킴 (매핑 정본은 scripts/derive-test-schemes.py — 그 표는 derive-test-schemes.test.sh 가 검증한다) ---
REPO_ROOT="$(cd ../../../.. && pwd)"
derived_for() { # 경로들 → 도출 스크립트가 직접 낸 스킴
  printf '%b\n' "$1" | python3 "$REPO_ROOT/scripts/derive-test-schemes.py" --changed | tr '\n' ' ' | sed 's/ $//'
}
WIDE='M\tDomain/Sources/Events/TodoEvent.swift\nM\tTodoCalendarApp/AppExtensions/Widget/Foo.swift\nM\tPresentations/AIAgentScene/Sources/B.swift'
assert_eq "스킴 섹션 = 도출 스크립트 결과" "$(derived_for 'Domain/Sources/Events/TodoEvent.swift\nTodoCalendarApp/AppExtensions/Widget/Foo.swift\nPresentations/AIAgentScene/Sources/B.swift')" "$(schemes_for "$WIDE")"
assert_contains "스킴 섹션이 손 매핑에 없던 스킴까지 낸다 (위 단언이 빈 값끼리 같아 통과하지 않게)" "UnitTestHelpKit" "$(schemes_for "$WIDE")"
assert_eq "모듈 테스트 경로 → 그 스킴만" "Repository" "$(schemes_for 'M\tRepository/Tests/FooTests.swift')"
assert_eq "rename → 옛 경로·새 경로 둘 다 도출에 넘긴다" "AIAgentScene Repository" "$(schemes_for 'R100\tRepository/Tests/OldTests.swift\tPresentations/AIAgentScene/Tests/NewTests.swift')"
assert_eq "docs만 → 테스트 무관" "(테스트 무관 변경)" "$(schemes_for 'M\tdocs/spec/foo.md')"

failing_derive_run() { # 도출 스크립트가 실패하는 트리에서 impact-check 를 돌린다 → "exit=<코드>" + stderr
  local tree; tree=$(mktemp -d)
  mkdir -p "$tree/.claude/skills/implement/scripts" "$tree/scripts"
  cp impact-check.sh "$tree/.claude/skills/implement/scripts/"
  printf 'import sys\nsys.stderr.write("Foo/Project.swift: 못 읽는 의존\\n")\nsys.exit(1)\n' > "$tree/scripts/derive-test-schemes.py"
  local err
  err=$(printf 'M\tDomain/Sources/Foo.swift\n' | bash "$tree/.claude/skills/implement/scripts/impact-check.sh" --stdin 2>&1 >/dev/null)
  echo "exit=$? $err"
  rm -rf "$tree"
}
FAILED_RUN=$(failing_derive_run)
assert_contains "도출 실패 → 0 아닌 코드로 끝난다" "^exit=[1-9]" "$FAILED_RUN"
assert_contains "도출 실패 → 도출 스크립트의 stderr 를 그대로 낸다" "Foo/Project.swift: 못 읽는 의존" "$FAILED_RUN"

# --- tuist generate 감지 ---
assert_eq "수정만 → 불필요" "불필요" "$(tuist_for 'M\tDomain/Sources/Foo.swift')"
assert_contains "추가 → 필요" "필요" "$(tuist_for 'A\tDomain/Sources/New.swift')"
assert_contains "삭제 → 필요" "필요" "$(tuist_for 'D\tDomain/Sources/Old.swift')"
assert_contains "이동(R) → 필요" "필요" "$(tuist_for 'R100\tDomain/Sources/Old.swift\tDomain/Sources/New.swift')"
assert_eq "비소스 추가(A) → 불필요" "불필요" "$(tuist_for 'A\tdocs/spec/new.md')"
assert_eq "비소스 추가(.claude) → 불필요" "불필요" "$(tuist_for 'A\t.claude/skills/foo/SKILL.md')"
assert_contains "Project.swift 수정(M) → 필요" "필요" "$(tuist_for 'M\tPresentations/SettingScene/Project.swift')"
assert_contains "Tuist helper 수정(M) → 필요" "필요" "$(tuist_for 'M\tTuist/ProjectDescriptionHelpers/Project+Templates.swift')"
assert_contains "Package.swift 수정(M) → 필요" "필요" "$(tuist_for 'M\tPackage.swift')"

# --- 짝 위치 경고 (stdin 모드는 파일 존재 기반 경고만) ---
assert_eq "pr_test.yml 변경 → 경고 없음 (스킴 목록이 도출로 바뀌어 동기화할 짝이 없다)" "(해당 없음)" "$(pairs_for 'M\t.github/workflows/pr_test.yml')"
assert_eq "경고 없음 → 해당 없음" "(해당 없음)" "$(pairs_for 'M\tdocs/foo.md')"

# --- git 모드 테스트 공통 (임시 repo 를 만들어 --base 로 돌린다) ---
SCRIPT_DIR="$(pwd)"
init_temp_repo() { # → 새 repo 경로
  local repo; repo=$(mktemp -d)
  git -C "$repo" init -q .
  git -C "$repo" config user.email t@t
  git -C "$repo" config user.name t
  printf '%s' "$repo"
}
section_in_repo() { # repo 섹션이름 → 그 섹션 본문
  (cd "$1" && bash "$SCRIPT_DIR/impact-check.sh" --base HEAD | awk -v h="## $2" '$0 == h {flag=1; next} /^## /{flag=0} flag')
}

# --- dbVersion 짝 경고 ---
pairs_in_repo() { # migrateCase(빈문자열이면 미추가) migrationImpleTouched(y/n) → 짝 섹션
  local repo; repo=$(init_temp_repo)
  (
    cd "$repo" || exit 1
    mkdir -p TodoCalendarApp/Sources Repository/A Repository/B "Repository/Setting/Migration"
    printf '    static let dbVersion: Int32 = 6\n    static let googleCalendarDBVersion: Int32 = 0\n' > TodoCalendarApp/Sources/AppEnvironment.swift
    printf 'struct TableA {\n    static func migrateStatement(for v: Int32) -> String? {\n        switch v {\n        case 0: return nil\n        default: return nil\n        }\n    }\n    var pad = 0\n}\n' > Repository/A/TableA.swift
    cp Repository/A/TableA.swift Repository/B/TableB.swift
    printf 'final class AppDataMigrationImple {\n    var pad = 0\n}\n' > Repository/Setting/Migration/AppDataMigrationImple.swift
    git add -A; git commit -qm base
    sed -i '' 's/dbVersion: Int32 = 6/dbVersion: Int32 = 7/' TodoCalendarApp/Sources/AppEnvironment.swift
    # 무관한 테이블의 migrateStatement 근처를 항상 건드린다 — 컨텍스트 확장 미탐 회귀 감시
    sed -i '' 's/var pad = 0/var pad = 1/' Repository/B/TableB.swift
    [ -n "$1" ] && sed -i '' "s/        case 0: return nil/        case $1: return nil\n        case 0: return nil/" Repository/A/TableA.swift
    [ "$2" = "y" ] && sed -i '' 's/var pad = 0/var pad = 1/' Repository/Setting/Migration/AppDataMigrationImple.swift
  )
  section_in_repo "$repo" "짝지어진 두 위치"
  rm -rf "$repo"
}
assert_contains "dbVersion↑ + case 미추가 → migrateStatement 경고" "case 6 추가가 함께 안 됨" "$(pairs_in_repo '' y)"
assert_contains "dbVersion↑ + 마이그레이션 스텝 미변경 → AppDataMigrationImple 경고" "AppDataMigrationImple" "$(pairs_in_repo 6 n)"
assert_eq "dbVersion↑ + 세 위치 전부 → 경고 없음" "(해당 없음)" "$(pairs_in_repo 6 y)"

# --- 외부 캘린더 DB 짝 경고 (서비스별로 따로 센다) ---
pairs_in_external_repo() { # migrateCase(빈문자열이면 미추가) externalMigrationTouched(y/n) → 짝 섹션
  local repo; repo=$(init_temp_repo)
  (
    cd "$repo" || exit 1
    mkdir -p TodoCalendarApp/Sources Repository/A "Repository/Event/ExternalCalendar" "Repository/Setting/Migration"
    printf '    static let dbVersion: Int32 = 7\n    static let googleCalendarDBVersion: Int32 = 1\n    static let appleCalendarDBVersion: Int32 = 1\n' > TodoCalendarApp/Sources/AppEnvironment.swift
    printf 'struct TableA {\n    static func migrateStatement(for v: Int32) -> String? {\n        switch v {\n        case 0: return nil\n        default: return nil\n        }\n    }\n    var pad = 0\n}\n' > Repository/A/TableA.swift
    printf 'final class ExternalCalendarDBMigrationImple {\n    var pad = 0\n}\n' > Repository/Event/ExternalCalendar/ExternalCalendarDBMigrationImple.swift
    printf 'final class AppDataMigrationImple {\n    var pad = 0\n}\n' > Repository/Setting/Migration/AppDataMigrationImple.swift
    git add -A; git commit -qm base
    sed -i '' 's/googleCalendarDBVersion: Int32 = 1/googleCalendarDBVersion: Int32 = 2/' TodoCalendarApp/Sources/AppEnvironment.swift
    [ -n "$1" ] && sed -i '' "s/        case 0: return nil/        case $1: return nil\n        case 0: return nil/" Repository/A/TableA.swift
    [ "$2" = "y" ] && sed -i '' 's/var pad = 0/var pad = 1/' Repository/Event/ExternalCalendar/ExternalCalendarDBMigrationImple.swift
  )
  section_in_repo "$repo" "짝지어진 두 위치"
  rm -rf "$repo"
}
assert_contains "googleCalendarDBVersion↑ + case 미추가 → migrateStatement 경고" "case 1 추가가 함께 안 됨" "$(pairs_in_external_repo '' y)"
assert_contains "googleCalendarDBVersion↑ + 외부 마이그레이션 미변경 → ExternalCalendarDBMigrationImple 경고" "runGoogleCalendarDBMigration" "$(pairs_in_external_repo 1 n)"
assert_eq "googleCalendarDBVersion↑ + 세 위치 전부 → 경고 없음" "(해당 없음)" "$(pairs_in_external_repo 1 y)"

# --- 테스트 고정 sleep 경고 (testability §9) ---
sleep_in_repo() { # 추가할 테스트 줄 · 대상(tracked/untracked/source) → 테스트 대기 섹션
  local repo; repo=$(init_temp_repo)
  (
    cd "$repo" || exit 1
    mkdir -p Domain/Tests Domain/Sources
    printf 'final class FooTests {\n}\n' > Domain/Tests/FooTests.swift
    printf 'final class Foo {\n}\n' > Domain/Sources/Foo.swift
    git add -A; git commit -qm base
    case "$2" in
      tracked) printf '%s\n' "$1" >> Domain/Tests/FooTests.swift ;;
      untracked) printf '%s\n' "$1" > Domain/Tests/NewTests.swift ;;
      source) printf '%s\n' "$1" >> Domain/Sources/Foo.swift ;;
      renamed)
        printf 'final class SleepTests {\n%s\n}\n' "$1" > Domain/Tests/SleepTests.swift
        git add -A; git commit -q --amend -m base
        git mv Domain/Tests/SleepTests.swift Domain/Tests/RenamedTests.swift ;;
    esac
  )
  section_in_repo "$repo" "테스트 대기"
  rm -rf "$repo"
}
assert_contains "기존 테스트에 Task.sleep 추가 → 경고" "FooTests.swift" "$(sleep_in_repo '        try await Task.sleep(for: .milliseconds(50))' tracked)"
assert_contains "새 테스트 파일의 Task.sleep → 경고" "NewTests.swift" "$(sleep_in_repo '        try await Task.sleep(nanoseconds: 50_000_000)' untracked)"
assert_eq "프로덕션 코드의 Task.sleep → 경고 없음" "(해당 없음)" "$(sleep_in_repo '        try await Task.sleep(for: .seconds(1))' source)"
assert_eq "sleep 이 든 테스트 파일을 rename 만 함 → 경고 없음" "(해당 없음)" "$(sleep_in_repo '        try await Task.sleep(for: .milliseconds(50))' renamed)"
assert_eq "sleep 없는 테스트 변경 → 경고 없음" "(해당 없음)" "$(sleep_in_repo '        #expect(value == 1)' tracked)"

echo "---"
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
