# App Store 스크린샷 (`deliver` 규약)

ASC에 올릴 6.9" 스크린샷을 담는 곳은 `fastlane/screenshots/<ASC 로케일>/<NN>_<슬러그>.png`이고,
파일명 앞 두 자리가 곧 ASC 진열 순서다. 31개 로케일 × 7장 = 217장, 전부 1320×2868 / 알파 없음.

슬롯은 `01_calendar`·`02_repeat-options`·`03_event-detail`·`04_google-event`·`05_widgets`·`06_appearance`·
`07_widget-style` 순이다. 대부분 화면 한 장을 베젤에 넣지만 둘은 합성한다. `05` 는 위젯 원본을 홈화면에 얹고,
`06` 은 설정 화면을 테마 네 개로 칠한 기기를 계단처럼 겹친다 (테마 목록은 합성 스크립트의 `THEME_LINEUP`).

자격증명·실행환경·업로드 검증·제출 순서는 [`docs/appstore-connect-operations.md`](../docs/appstore-connect-operations.md).

`screenshots/` 자체는 `.gitignore` 대상이다. 원고가 아니라 촬영·합성으로 다시 만드는 산출물이라
레포에 두지 않는다. 아래 절차로 언제든 재생성한다.

로케일 디렉토리명은 lproj 코드가 아니라 **ASC 코드**다 (6개가 다르다 — 매핑표는
[`metadata/README.md`](metadata/README.md)). 촬영·합성 스크립트에 넘기는 건 반대로 lproj 코드다.

## 재생성 → 업로드

```sh
# 1. 언어별 촬영 → snapshot-appstore/<lang>/ (시뮬레이터를 31번 돌린다)
bash scripts/capture-appstore-screenshots.sh --all

# 2. 업로드 규격 마케팅 스샷으로 합성 → fastlane/screenshots/<ASC 로케일>/
python3 scripts/compose-appstore-screenshots.py --all

# 3. 업로드 (바이너리·텍스트 메타데이터는 안 건드린다)
bundle exec fastlane ios upload_app_store_screenshots
```

`upload_app_store_screenshots`는 `overwrite_screenshots`로 돌아 ASC에 이미 올라간 스샷을 갈아끼운다.
두 번 돌려도 뒤에 덧붙지 않는다. 자격증명은 메타데이터 lane과 같은 `ASC_KEY_ID`·`ASC_ISSUER_ID`·`ASC_KEY_CONTENT`.

ASC에 올라간 뒤엔 로케일마다 7장이 `COMPLETE` 상태인지 확인한다 — 확인 방법은 운영 문서 §4.
심사 제출은 lane이 하지 않는다 — 업로드만 하고 제출은 콘솔에서 직접.

## iPhone Duo

Duo 는 화면이 둘이라 규격도 둘이다. 내부 화면은 2853×2007 가로, 커버 화면은 1398×2034 세로다.
캔버스가 화면 크기와 같아 캡션을 얹을 자리가 없으므로, 촬영 원본을 캡션·베젤 합성 없이 그대로 올린다.

같은 촬영·합성 명령이 함께 만든다. 출력은 `fastlane/screenshots_duo/<ASC 로케일>/` 의
`01_calendar-two-columns.png`(내부)·`02_calendar-cover.png`(커버)다.

`fastlane/screenshots/` 와 폴더를 나눈 이유가 있다. 지금 쓰는 fastlane 은 Duo 규격을 몰라서 같은 폴더에 두면
6.9" 업로드 lane 이 깨진다. fastlane 의 Duo 지원은 master 에만 들어갔고(2026-10-14, #30444) 2.241.0 에는 없다.
지원이 들어간 릴리스가 나오기 전까지는 Duo 스샷을 ASC 콘솔에서 수동으로 올린다.

## 촬영 전에 반드시 — 구글 아이콘 로컬 수정

`04_google-event`의 `Image("google_calendar_icon")`은 `Bundle.main`을 본다. 호스트 앱 없는 스냅샷 러너는
`xctest` 러너가 main bundle이라 이 에셋을 못 찾는다. **실패로 끊기지 않고 아이콘만 빠진 스샷이 나온다.**

촬영 전에 로컬에서 이렇게 고친다. **커밋하지 않는다** — 촬영 시점 로컬 수정으로만 두기로 한 결정이다.

1. `TodoCalendarApp/Resources/Assets.xcassets`의 `google_calendar_icon.imageset`과 `Contents.json`을
   `Presentations/EventDetailScene/Resources/Assets.xcassets/`로 복사
2. `Presentations/EventDetailScene/Project.swift`의 `Project.frameworkWithTest` 호출에
   `resources: ["Resources/**"]` 추가 — 파라미터 순서상 **`snapshotTests:` 앞**에 와야 한다
3. `GoogleCalendarEventDetailView.swift`의 `Image("google_calendar_icon")` **두 곳**을
   `Image("google_calendar_icon", bundle: .module)`로 교체
4. `tuist generate --no-open` → 촬영 → 1~3 원복 → `tuist generate --no-open`

## 촬영이 끊기면 남은 언어만 이어붙인다

31개 언어 × 약 3분 40초라 두 시간 가까이 걸린다. 한 번에 다 못 돌고 SIGTERM으로 끊기는 일이 있다.
이미 찍힌 언어는 `snapshot-appstore/<lang>/`에 남으니 **남은 언어만 넘기면 된다.**

```sh
bash scripts/capture-appstore-screenshots.sh ru uk ro el
python3 scripts/compose-appstore-screenshots.py ru uk ro el
```

## lane이 업로드 전에 끊는 세 가지

217장을 다 올린 뒤에 잘못을 알면 되돌릴 방법이 없어서, lane 진입 시 먼저 본다.

- **로케일 집합** — `screenshots/`의 로케일이 `metadata/`의 로케일 집합과 일치하는지.
  촬영이 중간에 끊겨 덜 합성된 경우가 여기서 걸린다 (한쪽에만 있는 로케일을 이름으로 찍어준다).
- **슬롯** — 로케일마다 `01`~`07` 일곱 장이 빠짐없이 있는지. 빠진 슬롯은 그냥 안 올라가고,
  남는 슬롯은 다른 언어와 진열 순서가 어긋난다.
- **업로드 규격** — 217장 전부 1320×2868인지, 알파 채널(PNG color type 4·6)이나 tRNS 투명도가 없는지.
  ASC는 투명도가 있는 스샷을 거부한다.
