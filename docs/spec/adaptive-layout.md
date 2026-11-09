# 적응형 레이아웃 상세 스펙 — Duo·iPad·창 크기

> 앱 창이 물리 화면과 다른 크기로 뜨는 환경(iPhone Duo 커버·내부 디스플레이, iPad 윈도우형 앱·Stage Manager)에서 창 크기와 size class, 그리고 메인 캘린더가 2단으로 펼쳐지는 기준을 정한다.

---

## 1. 크기 표

| 기기 | 자세·방향 | 창 (pt) | size class (h/v) | 비고 |
|---|---|---|---|---|
| iPhone Duo | 접힘 (커버) | 466×678 | Compact / Regular | 오른쪽 열을 카메라·시계·네트워크 표시가 차지한다. 콘텐츠는 safe area 안에서 끝난다 |
| iPhone Duo | 펼침 (내부) | 951×669 | Regular / Regular | 가로가 긴 창이다. 오른쪽 위에 시스템 상태 영역이 겹친다 |
| iPhone Duo | 중간 (반쯤 접힘) | 951×669 | Regular / Regular | 펼침과 같다 |
| iPhone 17 | 세로 | 402×874 | Compact / Regular | |
| iPhone 17 | 가로 | (실측 대기) | Compact / Compact | Apple 기기별 size class 기준값이다 |
| iPhone 17 Pro Max | 세로 | 440×956 | Compact / Regular | |
| iPhone 17 Pro Max | 가로 | 956×440 | Regular / Compact | |
| iPad Pro 13" | 전체 화면 세로 | 1032×1376 | Regular / Regular | |
| iPad Pro 13" | 전체 화면 가로 | 1376×1032 | Regular / Regular | |
| iPad Pro 13" | 윈도우 1/2 (가로 화면) | 698×932 | Regular / Regular | 윈도우형 앱 모드에서 창을 화면 폭의 절반으로 맞춘 값이다. 창은 끌어서 맞추므로 폭이 조금씩 다르다 |
| iPad Pro 13" | 윈도우 1/3 (가로 화면) | 489×932 | Compact / Regular | 같은 모드에서 화면 폭의 3분의 1로 맞춘 값이다 |
| iPad Pro 13" | Stage Manager | 438×932 ~ 859×995 | Compact / Regular ~ Regular / Regular | 창을 끌어 재면서 얻은 범위다. 438×932 는 Compact / Regular 이고 685×932 는 Regular / Regular 다 |

- iPhone 행은 iOS 27.1 SDK 로 빌드한 앱 기준이다. iOS 27.0 SDK 로 빌드하면 Duo 에서 창이 80pt 줄어든 호환 모드로 뜬다.
- 펼침과 접힘을 오갈 때 앱을 다시 실행하지 않아도 창이 새 크기를 따른다. iPad 도 창 크기를 바꾸면 재실행 없이 따라온다.
- iPad 행은 iOS 26.5 시뮬레이터 실측이다. 이 버전의 멀티태스킹 설정은 전체 화면 앱·윈도우형 앱·스테이지 매니저 셋이고 Split View 는 없다.
- Duo 내부에는 앱 창 크기를 바꾸거나 화면을 나누는 시스템 기능이 없다. 창 크기는 자세로만 바뀐다.

## 2. 2단 전환 기준

메인 캘린더는 창의 size class 가 **horizontal Regular 이고 vertical Regular 일 때** 2단(달력 · 이벤트 목록)으로 펼친다. 그 밖에는 지금처럼 1단이다.

| 환경 | size class (h/v) | 단 |
|---|---|---|
| Duo 내부 — 펼침·중간 | Regular / Regular | 2단 |
| Duo 커버 | Compact / Regular | 1단 |
| 일반 iPhone 세로 | Compact / Regular | 1단 |
| 일반 iPhone 가로 — Pro Max | Regular / Compact | 1단 — vertical 이 Compact 다 |
| 일반 iPhone 가로 — 그 밖 | Compact / Compact | 1단 — vertical 이 Compact 다 |
| iPad 전체 화면 세로·가로 | Regular / Regular | 2단 |
| iPad 윈도우 1/2 | Regular / Regular | 2단 |
| iPad 윈도우 1/3 | Compact / Regular | 1단 |
| iPad Stage Manager | 창 크기에 따라 Compact / Regular 또는 Regular / Regular | 1단 또는 2단 — 창을 줄이고 늘리면 그 자리에서 바뀐다 |

- 기기 이름이나 pt 문턱값이 아니라 size class 로 정한다. 새 기기가 나와도 시스템이 주는 값으로 따라간다.
- 펼침·접힘으로 size class 가 바뀌면 그 자리에서 단 수가 바뀐다 (1절).

## 3. 2단 구성

- **왼쪽** — 수직 연속 달력이다. 여러 달을 위아래로 잇고, 제스처 한 번에 한 달씩 스냅한다. 포커스 월 밖 날짜는 흐리게 그린다.
- **오른쪽** — 1단 일별 목록을 그대로 두고, 그 아래에 다음날 섹션을 이어 한 스크롤로 내려간다. 다음날 섹션에 일정이 없으면 "일정 없음" 을 보인다.
- **폭** — 오른쪽이 창 폭의 40% 를 쓰되 560pt 를 넘지 않는다. 남는 폭은 왼쪽 달력이 가진다. 두 칸 사이에는 연한 구분선이 있다.
- **헤더** — 2단에서는 이전·다음 달 버튼을 숨기고, 제목이 그 자리를 비워 두지 않는다. 달 이동은 왼쪽 달력 스크롤로 한다.
- **입력** — 오늘로 가기·날짜 점프·AI 입력·음성 입력 스크롤·키보드 올림은 2단에서도 오른쪽 칸에서 동작한다. 1단의 달력 접기와 당겨서 펼치기는 2단에 없다.

## 4. 단 전환 시 상태

- 포커스 월과 선택일은 1단과 2단이 한 값을 같이 쓴다. 단 수가 바뀌어도 보던 달과 고른 날이 그대로다.
- 2단에서 고른 날은 1단으로 돌아왔을 때 포커스 월 화면이 그대로 보인다. 다른 달은 1단이 기억하던 선택이 아니라 그 달의 기본 선택(오늘 또는 1일)을 보인다.
- 2단 화면은 처음 2단이 될 때 만들어지고, 그 뒤로는 1단에서도 내리지 않는다.

## 5. 넓은 창의 시트 폭

- **바텀 슬라이드 시트** — 본문 폭은 580pt 를 넘지 않고, 하단에 붙어 가로 가운데에 놓인다. 창 폭이 580pt 이하면 창 폭을 다 쓴다. 본문 밖의 위쪽과 좌우는 모두 딤 영역이라 탭 동작이 같다.
- **page sheet** — 앱이 폭을 지정하지 않고 시스템 폭을 쓴다. iPad 전체 화면 가로 실측값은 약 580pt 다. 바텀 슬라이드 상한을 이 값에 맞춰 두 시트 폭이 같아 보이게 했다.
- **Paywall** — 전체 화면을 유지하고 헤더·본문·구매 버튼이 가운데 580pt 열에 든다. 배경과 결제 처리 스크림은 창 전체를 덮는다. 창 폭이 580pt 이하면 창 폭을 다 쓴다.
- **공유·액션 시트** — iPad 에서 창 가운데에 화살표 없이 뜬다.

## 6. 창 제어 버튼

- 윈도우형 앱과 Stage Manager 에서는 창 왼쪽 위에 창 제어 버튼이 놓이고, 이 자리는 safe area 에 안 잡힌다.
- 앱이 창 왼쪽 위에 직접 그리는 제목 줄(메인 헤더·Paywall 헤더)은 시스템의 corner adaptation 값으로 비킨다. pt 를 박지 않는다.
- 시스템 바와 시트 안 헤더는 대상이 아니다. iPhone 에는 창 제어 버튼이 없어 이 기준을 적용하지 않는다.
