#!/bin/bash
# 테스트 실행용 시뮬레이터를 확보하고 UDID 를 표준출력으로 돌려준다.
#
# usage:
#   UDID="$(scripts/ensure-test-simulator.sh)"
#   xcodebuild test -destination "platform=iOS Simulator,id=$UDID" ...
#
# 로컬(run-all-tests.sh)과 CI(pr_test.yml)가 이 스크립트 하나를 공유한다.
# 양쪽이 각자 destination 을 박아두면 서로 다른 OS 로 갈리고, 그중 한쪽 런타임이
# Xcode 갱신으로 사라져도 다른 쪽은 초록이라 발견이 늦는다.
set -euo pipefail

SIMULATOR_NAME='iPhone 16'
SIMULATOR_DEVICE_TYPE='com.apple.CoreSimulator.SimDeviceType.iPhone-16'
SIMULATOR_RUNTIME='com.apple.CoreSimulator.SimRuntime.iOS-18-0'
RUNTIME_LABEL='iOS 18.0'

simulator_udid() {
    xcrun simctl list devices available --json \
        | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if not runtime.endswith("iOS-18-0"):
        continue
    for device in devices:
        if device["name"] == name:
            print(device["udid"])
            sys.exit(0)
' "$SIMULATOR_NAME"
}

udid="$(simulator_udid)"
if [ -n "$udid" ]; then
    echo "$udid"
    exit 0
fi

if ! xcrun simctl list runtimes | grep -q "$RUNTIME_LABEL"; then
    cat >&2 <<MSG
✗ $RUNTIME_LABEL 시뮬레이터 런타임이 없다.
  Xcode 갱신으로 런타임이 빠졌으면 다시 설치하거나,
  이 스크립트의 SIMULATOR_RUNTIME·RUNTIME_LABEL 을 설치된 런타임으로 올려라.
  여기 한 곳만 고치면 로컬과 CI 가 함께 따라온다.
MSG
    exit 1
fi

echo "▶︎ '$SIMULATOR_NAME' 생성 ($RUNTIME_LABEL)" >&2
xcrun simctl create "$SIMULATOR_NAME" "$SIMULATOR_DEVICE_TYPE" "$SIMULATOR_RUNTIME"
