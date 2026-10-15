#!/bin/bash
# asc-creative-assets.rb 의 네트워크 없이 도는 가드 회귀 테스트.
# 자격증명을 전부 지운 채로 돌려 "검증이 인증보다 앞선다"까지 함께 확인한다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
PASS=0; FAIL=0

FIXTURE="$ROOT/snapshot-appstore/_creative_asc_test"
export CREATIVE_CONFIG_ROOT="$FIXTURE"
trap 'rm -rf "$FIXTURE"' EXIT

# ASC_SECRET_FILE 을 없는 경로로 돌려, 이 기기에 실제 secret/asc-api-key.json 이 있어도
# 테스트가 그걸 집어 네트워크를 타지 않게 한다.
run() {
  env -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_KEY_CONTENT \
    ASC_SECRET_FILE=/nonexistent/asc-api-key.json \
    bundle exec ruby scripts/asc-creative-assets.rb "$@" 2>&1
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

write_image() { # locale file width height mode
  mkdir -p "$FIXTURE/images/$1"
  python3 -c "from PIL import Image; Image.new('$5', ($3, $4)).save('$FIXTURE/images/$1/$2')"
}

write_valid_set() { # locale
  write_image "$1" header.png 3840 1646 RGB
  write_image "$1" search.png 3840 2560 RGB
}

# --- 인자 검증 ---
assert_contains "로케일 인자가 없으면 끊는다" \
  "--locale <ASC로케일> 또는 --all-locales" "$(run push)"
assert_contains "--locale 와 --all-locales 를 함께 주면 끊는다" \
  "함께 못 쓴다" "$(run push --locale ko --all-locales)"
assert_contains "모르는 로케일은 끊는다" \
  "모르는 로케일: xx-YY" "$(run push --locale xx-YY)"
assert_not_contains "그 오류에서 자격증명 안내가 뜨지 않는다" \
  "자격증명을 못 찾았다" "$(run push --locale xx-YY)"

# --- 이미지 가드 ---
assert_contains "이미지가 없으면 끊는다" \
  "ko/header.png — 파일이 없다" "$(run push --locale ko --dry-run)"

write_valid_set ko
write_image ko header.png 3840 2160 RGB
assert_contains "헤더가 3840×1646 이 아니면 끊는다" \
  "ko/header.png — 3840×2160" "$(run push --locale ko --dry-run)"

write_valid_set ko
write_image ko search.png 3840 3000 RGB
assert_contains "검색 결과가 높이 범위를 벗어나면 끊는다" \
  "ko/search.png — 3840×3000" "$(run push --locale ko --dry-run)"

write_valid_set ko
write_image ko search.png 3000 2560 RGB
assert_contains "검색 결과가 범위 안이어도 3:2 가 아니면 끊는다" \
  "3:2 가 아니다" "$(run push --locale ko --dry-run)"

write_valid_set ko
write_image ko header.png 3840 1646 RGBA
ALPHA="$(run push --locale ko --dry-run)"
assert_contains "알파 채널이 있으면 끊는다" "ko/header.png — 알파 채널이 있다" "$ALPHA"
assert_not_contains "알파 위반에서 자격증명 안내가 뜨지 않는다" "자격증명을 못 찾았다" "$ALPHA"

write_valid_set ko
printf 'not a png' > "$FIXTURE/images/ko/search.png"
assert_contains "PNG 가 아니면 끊는다" \
  "ko/search.png — PNG 가 아니다" "$(run push --locale ko --dry-run)"

# --- 위반을 전량 모은다 ---
rm -rf "$FIXTURE/images"
write_valid_set ko
write_image ko header.png 3840 1646 RGBA
ALL="$(run push --all-locales --dry-run)"
assert_contains "첫 위반에서 멈추지 않는다 (ko 알파)" "ko/header.png — 알파 채널이 있다" "$ALL"
assert_contains "첫 위반에서 멈추지 않는다 (ja 누락)" "ja/header.png — 파일이 없다" "$ALL"

# --- 가드를 통과하면 그제서야 인증으로 간다 ---
write_valid_set ko
assert_contains "가드를 통과한 dry-run 은 교체 판정을 위해 자격증명을 요구한다" \
  "자격증명을 못 찾았다" "$(run push --locale ko --dry-run)"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
