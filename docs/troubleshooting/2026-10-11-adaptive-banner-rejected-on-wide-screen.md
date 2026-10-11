---
issue: "#1255"
subdomain: Billing
symptoms: [Ad size will not fit on screen, adaptive banner 미표시, 배너 안 뜸, duo 펼침 배너, admob Code=0, 가로 긴 화면 배너]
resolution: fixed
---

# 가로가 긴 화면에서 adaptive 배너가 "Ad size will not fit on screen" 으로 거부된다

- **증상**: iPhone Duo 를 펼친 상태(화면 871x669)에서 하단 배너가 뜨지 않고 영역도 안 잡힌다. 접은 상태(466x678)와 일반 iPhone(393x852)에서는 정상이다. 앱을 펼친 채로 다시 시작해도 같다. `banner ad load failed: Error Domain=com.google.admob Code=0 "Ad size will not fit on screen."` 가 재시도 간격마다 쌓인다.
- **근본 원인**: Google Mobile Ads SDK 는 배너 폭을 **화면의 짧은 변 이하**로만 받는다. `currentOrientationAnchoredAdaptiveBanner(width:)` 에 가로가 긴 화면의 레이아웃 폭을 그대로 넘기면 그 폭이 짧은 변을 넘어 거부된다. duo 펼침에서 safe area 폭이 803 인데 짧은 변은 669 였다. 폭을 바꿔가며 실측한 경계가 정확히 짧은 변이다 — 803·728 실패, 669·600 성공.
- **해결**: `AdBannerSize.adSize(fittingWidth:within:)` 가 화면 크기를 함께 받아 `min(width, min(screenSize.width, screenSize.height))` 로 요청 폭을 제한한다. 광고 폭이 컨테이너보다 좁아질 수 있어 `AdBannerUIView` 가 `BannerView` 를 leading·trailing 대신 `centerXAnchor` 로 붙인다. 세로 화면에서는 레이아웃 폭이 늘 짧은 변 이하라 동작이 바뀌지 않는다.
- **기각 방향**: 컨테이너 높이 0 이 원인 — 로드 시점 높이 0 은 iPhone 16 에서도 같은데 거기선 성공해 기각했다 / `rootViewController` 미설정이 원인 — 설정해도 803 은 그대로 거부돼 기각했다 / 폭 상한을 IAB leaderboard 728 로 고정 — 728 도 거부돼 기각했다. 상한은 고정값이 아니라 화면에 달려 있다 / `isAdSizeValid` 가 adaptive 를 거부 — probe 로 `valid=1` 을 확인해 기각했다
