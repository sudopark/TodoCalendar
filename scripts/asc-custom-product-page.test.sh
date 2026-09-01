#!/bin/bash
# asc-custom-product-page.rb 의 네트워크 없이 도는 가드 회귀 테스트.
# 자격증명을 전부 지운 채로 돌려 "검증이 인증보다 앞선다"까지 함께 확인한다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
PASS=0; FAIL=0

FIXTURE="$ROOT/snapshot-appstore/_cpp_asc_test"
export CPP_CONFIG_ROOT="$FIXTURE"
trap 'rm -rf "$FIXTURE"' EXIT

# ASC_SECRET_FILE 을 없는 경로로 돌려, 이 기기에 실제 secret/asc-api-key.json 이 있어도
# 테스트가 그걸 집어 네트워크를 타지 않게 한다.
run() {
  env -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_KEY_CONTENT \
    ASC_SECRET_FILE=/nonexistent/asc-api-key.json \
    bundle exec ruby scripts/asc-custom-product-page.rb "$@" 2>&1
}

assert_contains() { # desc pattern actual
  if printf '%s' "$3" | grep -qF -- "$2"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  pattern [$2] not in:"; printf '%s\n' "$3" | sed 's/^/    /'
  fi
}
assert_not_contains() { # desc pattern actual
  if printf '%s' "$3" | grep -qF -- "$2"; then
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  pattern [$2] unexpectedly present"
  else
    PASS=$((PASS+1))
  fi
}

write_page_config() { # scenes_json
  mkdir -p "$FIXTURE"
  cat > "$FIXTURE/pages.json" <<JSON
{ "page-a": { "ascPageId": "", "scenes": $1 } }
JSON
}

write_text() { # locale text
  mkdir -p "$FIXTURE/page-a/$1"
  printf '%s' "$2" > "$FIXTURE/page-a/$1/promotional_text.txt"
}

write_images() { # locale count
  mkdir -p "$FIXTURE/page-a/images/$1"
  rm -f "$FIXTURE/page-a/images/$1"/*.png
  for index in $(seq 1 "$2"); do
    printf 'x' > "$FIXTURE/page-a/images/$1/$(printf '%02d' "$index")_C$index.png"
  done
}

# --- 인자·설정 검증은 인증보다 앞선다 ---
write_page_config '["C1", "C2", "C3", "C4", "C5", "C6"]'
write_text ko "짧은 문구"
write_images ko 6

assert_contains "--page 와 --all-pages 를 함께 주면 끊는다" \
  "함께 못 쓴다" "$(run push-text --page page-a --all-pages --locale ko)"
assert_not_contains "그 오류에서 자격증명 안내가 뜨지 않는다" \
  "자격증명을 못 찾았다" "$(run push-text --page page-a --all-pages --locale ko)"

assert_contains "모르는 페이지는 끊는다" \
  "모르는 페이지: nope" "$(run push-text --page nope --locale ko)"

assert_contains "페이지 인자가 없으면 끊는다" \
  "--page <page_id> 또는 --all-pages" "$(run push-text --locale ko)"

assert_contains "로케일 인자가 없으면 끊는다" \
  "--locale <ASC로케일> 또는 --all-locales" "$(run push-text --page page-a)"

# --- pages.json 자체 검증 ---
write_page_config '["C1", "C2", "C3", "C4", "C5"]'
assert_contains "페이지당 6장이 아니면 끊는다" \
  "장면이 5개다" "$(run push-text --page page-a --locale ko)"

# --- 프로모션 문구 상한 ---
write_page_config '["C1", "C2", "C3", "C4", "C5", "C6"]'
LONG_TEXT="$(python3 -c 'print("가" * 171)')"
write_text ko "$LONG_TEXT"
write_text ja "$LONG_TEXT"
OVERFLOW="$(run push-text --page page-a --all-locales --dry-run)"
assert_contains "170자 초과를 잡는다" "171자 (상한 170)" "$OVERFLOW"
assert_contains "위반을 첫 건에서 멈추지 않고 전량 모은다" "page-a/ja" "$OVERFLOW"
assert_not_contains "상한 위반에서 자격증명 안내가 뜨지 않는다" "자격증명을 못 찾았다" "$OVERFLOW"

write_text ko "짧은 문구"
assert_contains "원고가 없는 로케일을 잡는다" \
  "promotional_text.txt 이 없거나 비었다" "$(run push-text --page page-a --locale zh-Hans)"

# --- 이미지 장수 ---
write_images ko 5
assert_contains "이미지가 6장이 아니면 끊는다" \
  "이미지가 5장이다" "$(run push-images --page page-a --locale ko --dry-run)"
assert_not_contains "장수 오류에서 자격증명 안내가 뜨지 않는다" \
  "자격증명을 못 찾았다" "$(run push-images --page page-a --locale ko --dry-run)"

# --- 검증을 통과하면 그제서야 인증으로 간다 ---
write_images ko 6
assert_contains "검증을 통과한 dry-run 은 계획을 찍는다" \
  "--dry-run — 아무것도 올리지 않았다" "$(run push-images --page page-a --locale ko --dry-run)"
assert_contains "push-text 는 dry-run 도 ASC 를 읽어야 해 자격증명을 요구한다" \
  "자격증명을 못 찾았다" "$(run push-text --page page-a --locale ko --dry-run)"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
