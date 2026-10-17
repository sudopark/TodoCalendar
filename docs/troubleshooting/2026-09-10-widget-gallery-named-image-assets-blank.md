---
subdomain: Settings
symptoms: [위젯 갤러리 아이콘 안보임, AI 위젯 아이콘 빈칸, custom.calendar.badge.sparkles, small_icon, Image 이름 해석 실패, Bundle.main]
resolution: fixed
---

# 위젯 갤러리에서 AI·다음이벤트 위젯 아이콘이 빈칸으로 나온다

- **증상**: 앱 내 위젯 갤러리 목록·미리보기에서 AI 명령 위젯 아이콘과 다음이벤트 사각형 위젯의 앱 심볼이 안 보인다. 홈화면에 얹은 실제 위젯은 정상.
- **근본 원인**: `WidgetScenes` 의 미리보기 뷰가 `Image("custom.calendar.badge.sparkles")` / `Image("small_icon")` 처럼 번들 없이 이름으로 부르는데, SwiftUI 는 이를 `Bundle.main` 에서 찾는다. 두 에셋은 위젯 확장 타겟 카탈로그(`TodoCalendarApp/AppExtensions/Widget/Resources/Assets.xcassets`)에만 있었다. 갤러리는 앱 프로세스에서 도니 `Bundle.main` 이 앱 번들이라 못 찾고, 실제 위젯은 확장 프로세스라 같은 코드가 정상 동작한다 — "실기는 되는데 갤러리만 깨진다"가 이 구조에서 나온다.
- **해결**: 두 에셋을 `Presentations/WidgetScenes/Resources/Assets.xcassets` 로 옮기고 `WidgetScenes` 에 `resources: ["Resources/**"]` 를 붙여 뷰가 `bundle: .module` 로 부르게 했다. 정적 프레임워크 리소스 번들이 앱과 확장 양쪽 산출물에 복사되므로(`TodoCalendarAppWidget.appex/WidgetScenes_WidgetScenes.bundle/Assets.car` 로 확인) 두 프로세스가 같은 번들에서 해석한다. 회귀는 `WidgetSceneImageAssetTests` 가 잡는다. 앱 카탈로그 사본은 유저 지시로 추가했다 — 현재 코드가 참조하진 않는다.
- **기각 방향**: 앱 카탈로그에만 사본 추가 — `app_symbol` 선례가 이 형태지만, WidgetScenes 뷰가 이름으로 부르는 에셋이 늘 때마다 앱 카탈로그에 같이 넣어야 하는 짝이 생겨 같은 결함이 재발한다.
