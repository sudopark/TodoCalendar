#!/bin/bash
# asc-in-app-event.rb 의 네트워크 없이 도는 가드 회귀 테스트.
# 자격증명을 전부 지운 채로 돌려 "검증이 인증보다 앞선다"까지 함께 확인한다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
PASS=0; FAIL=0

FIXTURE="fastlane/in_app_events/_test_fixture"
trap 'rm -rf "$ROOT/$FIXTURE"' EXIT

# ASC_SECRET_FILE 을 없는 경로로 돌려, 이 기기에 실제 secret/asc-api-key.json 이 있어도
# 테스트가 그걸 집어 네트워크를 타지 않게 한다.
run() { # 인자를 그대로 넘기고 stdout+stderr 를 합쳐 돌려준다
  env -u ASC_KEY_ID -u ASC_ISSUER_ID -u ASC_KEY_CONTENT \
    ASC_SECRET_FILE=/nonexistent/asc-api-key.json \
    bundle exec ruby scripts/asc-in-app-event.rb "$@" 2>&1
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

write_locale() { # locale name short long
  mkdir -p "$FIXTURE/$1"
  printf '%s' "$2" > "$FIXTURE/$1/name.txt"
  printf '%s' "$3" > "$FIXTURE/$1/short_description.txt"
  printf '%s' "$4" > "$FIXTURE/$1/long_description.txt"
}

# --- badge 검증은 인증보다 앞선다 ---
assert_contains "badge 오타가 네트워크 전에 끊긴다" "badge 는 다음 7종" "$(run set-badge 123 NOT_A_BADGE)"
assert_not_contains "badge 오타에서 자격증명 안내가 뜨지 않는다" "자격증명을 못 찾았다" "$(run set-badge 123 NOT_A_BADGE)"

# --- 자격증명 가드 ---
CREDS="$(run list)"
assert_contains "자격증명 부재를 알린다" "자격증명을 못 찾았다" "$CREDS"
assert_contains "secret 파일 경로를 안내한다" "asc-api-key.json" "$CREDS"
assert_contains "환경변수 대안도 안내한다" "ASC_KEY_ID" "$CREDS"

# --- 인자 파싱 ---
assert_contains "인자 없으면 usage" "usage:" "$(run)"
assert_contains "--event 값이 또 다른 플래그면 usage" "usage:" "$(run push-text --event --dry-run)"
assert_contains "없는 이벤트 디렉토리를 짚는다" "이벤트 원고 디렉토리를 먼저 만들어라" "$(run push-text --event nope --locale ko --dry-run)"

# --- 원고 검증 ---
rm -rf "$FIXTURE"
write_locale ko "가나다라마바사아자차카타파하가나다라마바사아자차카타파하가나다" "짧은 설명" "상세 설명"
OVER="$(run push-text --event _test_fixture --locale ko --dry-run)"
assert_contains "name 31자를 상한 위반으로 잡는다" "ko name — 31자 (상한 30)" "$OVER"
assert_not_contains "상한 위반이면 인증까지 가지 않는다" "자격증명을 못 찾았다" "$OVER"

rm -rf "$FIXTURE"
write_locale ko "정상 이름" "짧은 설명" "상세 설명"
rm "$FIXTURE/ko/long_description.txt"
assert_contains "파일 결손을 잡는다" "ko long_description — 파일이 없거나 비었다" \
  "$(run push-text --event _test_fixture --locale ko --dry-run)"

rm -rf "$FIXTURE"
write_locale ko "정상 이름" "짧은 설명" "상세 설명"
assert_contains "--locale/--all-locales 없으면 끊는다" "--all-locales 중 하나가 필요하다" \
  "$(run push-text --event _test_fixture --dry-run)"
assert_contains "lproj 코드를 쓰면 ASC 코드임을 알린다" "lproj 가 아니라 ASC 코드다" \
  "$(run push-text --event _test_fixture --locale de --dry-run)"
printf '{"ascEventId":"6806709988"}' > "$FIXTURE/event.json"
assert_contains "유효한 원고는 검증을 통과해 인증까지 간다" "자격증명을 못 찾았다" \
  "$(run push-text --event _test_fixture --locale ko --dry-run)"
rm -f "$FIXTURE/event.json"

# --- --event 슬러그를 ASC 이벤트 id 로 오인하지 않는다 ---
rm -rf "$FIXTURE"
write_locale ko "정상 이름" "짧은 설명" "상세 설명"
NOCONF="$(run push-text --event _test_fixture --locale ko --dry-run)"
assert_contains "event.json 없으면 ascEventId 를 요구한다" "ascEventId 를 담을 설정 파일이 필요하다" "$NOCONF"
assert_not_contains "설정이 없으면 인증까지 가지 않는다" "자격증명을 못 찾았다" "$NOCONF"

printf '{"ascEventId":""}' > "$FIXTURE/event.json"
EMPTYID="$(run push-text --event _test_fixture --locale ko --dry-run)"
assert_contains "ascEventId 가 비면 채우라고 짚는다" "ascEventId 가 비었다" "$EMPTYID"
assert_not_contains "빈 ascEventId 로 인증까지 가지 않는다" "자격증명을 못 찾았다" "$EMPTYID"

printf '{"ascEventId":"6806709988"}' > "$FIXTURE/event.json"
assert_contains "ascEventId 가 차면 인증까지 간다" "자격증명을 못 찾았다" \
  "$(run push-text --event _test_fixture --locale ko --dry-run)"

# --- push-images 는 합성 산출물이 없으면 인증 전에 끊는다 ---
rm -rf "$FIXTURE"
write_locale ko "정상 이름" "짧은 설명" "상세 설명"
printf '{"ascEventId":"6806709988"}' > "$FIXTURE/event.json"
NOIMG="$(run push-images --event _test_fixture --locale ko --dry-run)"
assert_contains "합성 이미지 결손을 짚는다" "event-card_1920x1080.png — 없다" "$NOIMG"
assert_contains "compose 를 먼저 돌리라고 안내한다" "compose-event-images.py 를 먼저 돌려라" "$NOIMG"
assert_not_contains "이미지 결손이면 인증까지 가지 않는다" "자격증명을 못 찾았다" "$NOIMG"

mkdir -p "$FIXTURE/images/ko"
python3 - "$FIXTURE/images/ko" <<'PYIMG'
import sys
from pathlib import Path
from PIL import Image
directory = Path(sys.argv[1])
Image.new("RGB", (1920, 1080), "#000000").save(directory / "event-card_1920x1080.png")
Image.new("RGB", (1080, 1920), "#000000").save(directory / "event-detail_1080x1920.png")
PYIMG
assert_contains "이미지가 갖춰지면 인증까지 간다" "자격증명을 못 찾았다" \
  "$(run push-images --event _test_fixture --locale ko --dry-run)"

# --- 로케일 축이 fastlane/metadata 31개와 일치하는가 ---
EXPECTED_LOCALES=$(find fastlane/metadata -mindepth 1 -maxdepth 1 -type d \
  ! -name review_information ! -name trade_representative_contact_information \
  ! -name app_clip_review_information | wc -l | tr -d ' ')
rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
ALL="$(run push-text --event _test_fixture --all-locales --dry-run)"
assert_contains "--all-locales 는 metadata 로케일 전부를 본다" "$((EXPECTED_LOCALES * 3))건" "$ALL"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
