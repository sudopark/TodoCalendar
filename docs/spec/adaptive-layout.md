# 적응형 레이아웃 상세 스펙 — Duo·창 크기

> 앱 창이 물리 화면과 다른 크기로 뜨는 환경(iPhone Duo 커버·내부 디스플레이)에서 창 크기와 size class, 그리고 메인 캘린더가 2단으로 펼쳐지는 기준을 정한다.

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

- 위 값은 iOS 27.1 SDK 로 빌드한 앱 기준이다. iOS 27.0 SDK 로 빌드하면 Duo 에서 창이 80pt 줄어든 호환 모드로 뜬다.
- 펼침과 접힘을 오갈 때 앱을 다시 실행하지 않아도 창이 새 크기를 따른다.
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

- 기기 이름이나 pt 문턱값이 아니라 size class 로 정한다. 새 기기가 나와도 시스템이 주는 값으로 따라간다.
- 펼침·접힘으로 size class 가 바뀌면 그 자리에서 단 수가 바뀐다 (1절).
