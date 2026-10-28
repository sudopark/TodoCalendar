# 00 — 설계 단계

#1150 의 구조를 정하기까지 나온 글감. 착수 전이라 코드 변경은 없고 측정과 결정만 있다.

## 수치

| 항목 | 값 |
|---|---|
| Domain 전체 | 14,550줄 |
| 그중 `Imple` 선언을 포함한 파일 | 6,418줄 (44%) |
| `Usecases` 파일 중 `Imple` 포함 | 56개 중 35개 |
| `Domain/Sources/Repositories/` 의 `Imple` | 0건 |
| Presentation 이 소비하는 public usecase | 40개 |
| 그중 화면 모듈 2개 이상이 쓰는 것 | 34개 (85%) |
| 화면 모듈당 참조 서브도메인 | EventDetailScene 6 · SettingScene 6 · CalendarScenes 6 |
| 서브도메인 간 양방향 쌍 | 9개 → 오탐 제외 후 진짜 행위 의존 1건 |
| repository 포트 27개 중 서브도메인 경계를 넘는 참조 | 2건 |

## 틀린 가설

**"Domain 은 프로토콜 위주라 Interface 분리가 무의미하다."** 세어보니 44%가 구현이었다. 분리를 미루는 이유는 내용물이 없어서가 아니라 수직 축(서브도메인)과 수평 축(Interface/Impl)이 곱해져 타겟이 두 배가 되기 때문이다. 결론은 같아도 근거가 틀리면 다음 판단에서 엉뚱한 데로 간다.

**"다른 서브도메인의 repository 포트를 쓰면 안 된다."** `EventNotificationSettingUsecaseImple` 이 `EventNotificationRepository` 를 직접 받아 쓰고 있고 그게 맞는 설계였다. 지킬 불변식이 없는 얇은 저장소라 usecase 를 한 겹 세우면 위임만 하는 껍데기가 늘 뿐이다. 선은 repository 냐 usecase 냐가 아니라 **불변식이 어디 있느냐**다.

## 놀란 지점

`Models/Events/EventTag.swift:140,149` 가 `GoogleCalendar.Tag`·`AppleCalendar.Tag` 를 받는 init 을 갖고 있었다. 이벤트 태그 어휘가 외부 캘린더 구체 타입을 안다. `EventTagId.externalCalendar(serviceId:id:)` 케이스는 문자열이라 깨끗한데 init 두 개만 샜다.

`Event ↔ Account` 순환이 7 대 1 로 제일 무거웠는데, 실물을 열어보니 순환이 아니었다. External Calendar 서브도메인이 Event 밑과 Account 밑에 반씩 흩어져 있어서 순환처럼 보인 것이다. `docs/domain-context-map.md` 에는 이미 독립 Supporting 서브도메인으로 올라가 있었고, 코드 배치만 안 따라온 상태였다. 순환을 끊는 게 아니라 흩어진 걸 모으는 게 처방이었다.

`Presentations/Scenes/Sources/Factories.swift` 가 이미 `AccountUsecaseFactory`·`EventUsecaseFactory` 식으로 서브도메인별로 갈려 있었다. 축은 맞는데 타겟이 하나였다.

## 도구가 못 잡은 것

타입명 grep 으로 모듈 간 간선을 뽑을 때 `extension` 을 선언으로 세면 안 된다. `extension String` 하나 때문에 `String` 이 그 모듈 소유가 되면서 `Event → Support` 참조가 32건으로 부풀었다. 정규식에서 `extension` 을 빼니 실제값이 나왔다.

`Scope`·`Subject`·`Status`·`CodingKeys` 같은 중첩 타입 이름이 모듈 간 가짜 간선을 만든다. `Scope` 는 `Models/Ad/FullScreenAdExposureRecord.swift:14` 와 `Usecases/Account/.../ExternalService.swift:47` 에 각각 있는 별개 enum 인데 같은 이름이라 간선으로 잡혔다. 오탐 목록을 손으로 관리해야 했다.

**공개 시그니처에 남의 모델이 새는 것(전이 의존)은 어떤 도구도 안 잡는다.** 컴파일이 통과하기 때문이다. 순환과 미선언 import 는 tuist 가 막아주지만 이건 리뷰에서만 잡힌다.

## 결정의 근거가 된 기준

**그래프가 wide & shallow 해야 모듈 분리로 빌드 이득이 난다.** A→B→C→D 로 이어지는 linear 그래프면 아무리 쪼개도 병렬화가 안 된다. 이 프로젝트의 Presentation 층은 서로 참조하지 않아 이미 wide 하고, 병목은 `Domain` 단일 노드였다.

**목구멍은 하나가 아니라 셋이다.** `Domain` 본체만 갈라선 이득이 안 난다. `Supports/TestDoubles` 는 Domain 전체를 의존하고 모든 테스트 타겟이 이걸 의존하며, `Presentations/Scenes` 는 12개 서브도메인을 전부 참조하고 모든 Presentation 모듈이 이걸 의존한다. 셋이 같은 축으로 함께 갈려야 한다.

## 측정 스크립트

`scripts/` 에 넣어뒀다. 레포 루트 기준으로 `Domain/Sources` 를 읽으니, 분할 후에는 읽을 경로를 고쳐 다시 돌린다.

| 스크립트 | 뽑는 것 |
|---|---|
| `ctxmap.py` | 서브도메인별 파일 수, 모듈 간 간선, 양방향 쌍 |
| `leaks.py` | 순환 간선의 실물 — 어느 파일이 어느 타입 때문에 새는지 |
| `repoleak.py` | 서브도메인 경계를 넘는 repository 포트 참조 |
| `usecase_fanout.py` | usecase 별 소비 화면 수, 화면별 참조 서브도메인 수 |
| `target_graph.py` | 제안 분할 기준 모듈 그래프 + SCC 검출 |
