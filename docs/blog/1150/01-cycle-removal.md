# 01 — 순환 제거 (DP-1.1)

Domain 을 한 모듈로 둔 채 파일·타입만 옮겨서, 나중에 모듈로 떼어 낼 서브도메인 사이의 의존 그래프를 DAG 로 만든 단계다. 측정은 `scripts/target_graph.py` 로 한다.

## 측정 기준

- 파일 경로로 서브도메인을 정한다. `Device/`·`Migration/`·`Models/Place/` 는 일반 규칙보다 먼저 각각 `DeviceInterface`·`MigrationDomain`·`PlaceServiceInterface` 로 본다.
- 다른 서브도메인이 선언한 타입 이름이 소스에 나오면 간선 하나로 센다. 중첩 타입 이름(`Event`·`Scope`·`Subject`·`Tag`·`Constant` 등)과 `//` 주석 속 이름은 오탐이라 뺀다.
- 순환이 없으면 의존이 없는 쪽부터 추출 층을 낸다.

## 수치

| 항목 | 이동 전 | 이동 뒤 |
|---|---|---|
| 순환(SCC)에 묶인 서브도메인 | 7개 | 0개 |
| 서브도메인 사이 간선 쌍 | 38 | 31 |
| 간선을 만드는 타입 참조 | 144 | 121 |
| 양방향 쌍 | 7 | 0 |

이슈 설계의 이동 목록만 반영한 중간 측정에서는 순환이 6개 서브도메인에 남았다. ExternalCalendar 하나만 빠졌다.

## 틀린 가설

**"이슈에 적은 이동 목록만 반영하면 DAG 가 된다."** 실측해 보니 Account·Billing·Event·Notification·Setting·Support 여섯이 여전히 한 순환에 묶여 있었다. 목록은 양방향 쌍을 하나씩 보고 만든 것이라, 쌍 하나를 끊어도 세 서브도메인 이상을 도는 고리는 그대로 남았다. Setting→Billing→Setting 은 유료 기능 게이트가 테마 키를 통째로 받아서 생겼고, Notification→Support→Account→Notification 은 기기 정보가 피드백 쪽에 얹혀 있어서 생겼다.

## 놀란 지점

`PaidFeature.colorTheme` 이 `ColorSetKeys` 를 통째로 받고 있었지만, 게이트가 실제로 읽는 정보는 "커스텀 테마인가" 한 비트뿐이었다. 이 한 비트 때문에 Billing 이 Setting 의 테마 어휘 전체를 알았다. 연관값을 `isCustom: Bool` 로 줄이고, 키에서 그 비트를 뽑는 일은 `ColorSetKeys.paidFeature` 로 Setting 쪽에 두니 간선 방향이 Setting→Billing 하나로 정리됐다.

00 글감이 "`EventTag` 가 외부 캘린더 Tag 를 받는 init 을 갖는다" 고 적었는데, 그 init 들은 프로토콜 `EventTag` 가 아니라 구조체 `ExternalCalendarEventTag` 소속이었다. 파일 이름만 보고 extension 대상을 잡았다가 컴파일에서 걸렸다.

## 도구가 못 잡은 것

설계 단계 스크립트는 타입 이동을 "소유 모듈 표" 로 흉내 냈다. 이 방식은 옮긴 타입이 들고 가는 의존을 못 본다. `DefaultEventTagColorSetting` 을 Event 로 옮기는 것으로 표시하자 그래프는 깨끗해 보였지만, 실제로 파일을 옮기니 그 타입의 `update(_:)` 가 받는 `EditDefaultEventTagColorParams` 가 Setting 에 남아 Event→Setting 역방향 간선이 새로 생겼다. 흉내 표를 지우고 실제 파일 위치만으로 재도록 바꿨고, params 도 함께 옮겼다.

## 되돌린 결정

게이트의 순환을 처음엔 사용권·정책을 Setting 쪽에 모아 끊으려 했다. 유저가 "두 모듈이 같은 데이터를 필요로 하면 한쪽은 필요한 정보만 다시 정의해 의존한다" 는 원칙을 내놨고, 게이트·사용권·정책은 Billing 이 갖고 Billing 은 커스텀 여부만 받는 쪽으로 바뀌었다. 기기 정보도 같은 원칙으로 Notification·Support 어느 쪽에도 두지 않고 Device 로 뗐다.

## 이동 뒤

순환이 없어져 추출 층이 나온다. 층 번호가 작을수록 먼저 모듈로 뽑을 수 있다.

```
== 제안 분할 기준 모듈 간 간선 ==
  EventDomain              -> Kernel_Utils              14
  EventDomain              -> CalendarDomain            12
  ExternalCalendarDomain   -> EventDomain               12
  SettingDomain            -> EventDomain               11
  NotificationDomain       -> EventDomain                9
  AIDomain                 -> SupportDomain              8
  ExternalCalendarDomain   -> Kernel_Utils               6
  ExternalCalendarDomain   -> AccountDomain              5
  CalendarDomain           -> Kernel_Utils               4
  SettingDomain            -> Kernel_Utils               4
  BillingDomain            -> Kernel_Utils               4
  SupportDomain            -> Kernel_Utils               3
  SettingDomain            -> BillingDomain              3
  NotificationDomain       -> DeviceInterface            2
  AIDomain                 -> BillingDomain              2
  AdDomain                 -> BillingDomain              2
  AdDomain                 -> Kernel_Utils               2
  SupportDomain            -> DeviceInterface            2
  AIDomain                 -> Kernel_Utils               2
  AIDomain                 -> EventDomain                2
  AccountDomain            -> Kernel_Utils               2
  EventDomain              -> PlaceServiceInterface      1
  AdDomain                 -> SettingDomain              1
  AdDomain                 -> DeviceInterface            1
  SupportDomain            -> PlaceServiceInterface      1
  SupportDomain            -> AccountDomain              1
  AIDomain                 -> NotificationDomain         1
  AIDomain                 -> CalendarDomain             1
  AccountDomain            -> NotificationDomain         1
  SettingDomain            -> NotificationDomain         1
  EventDomain              -> MigrationDomain            1

== 남은 순환 (SCC) ==
  없음 — DAG

== 추출 층 (의존이 없는 쪽부터) ==
  0: DeviceInterface, Kernel_Utils, MigrationDomain, PlaceServiceInterface
  1: BillingDomain, CalendarDomain
  2: EventDomain
  3: NotificationDomain
  4: AccountDomain, SettingDomain
  5: AdDomain, ExternalCalendarDomain, SupportDomain
  6: AIDomain
```

## 이동 전

서브도메인 일곱이 한 덩어리 순환에 묶여 있다. 순환 밖에 있는 건 Calendar·AI·Ad·Kernel 뿐이다.

```
== 제안 분할 기준 모듈 간 간선 ==
  EventDomain              -> Kernel_Utils              14
  ExternalCalendarDomain   -> EventDomain               13
  EventDomain              -> CalendarDomain            12
  EventDomain              -> ExternalCalendarDomain    11
  ExternalCalendarDomain   -> AccountDomain              8
  AIDomain                 -> SupportDomain              8
  NotificationDomain       -> EventDomain                7
  SupportDomain            -> SettingDomain              6
  ExternalCalendarDomain   -> Kernel_Utils               6
  CalendarDomain           -> Kernel_Utils               4
  SettingDomain            -> Kernel_Utils               4
  EventDomain              -> SupportDomain              4
  BillingDomain            -> Kernel_Utils               4
  SupportDomain            -> Kernel_Utils               3
  SettingDomain            -> EventDomain                3
  EventDomain              -> NotificationDomain         3
  BillingDomain            -> SettingDomain              3
  AIDomain                 -> BillingDomain              2
  AdDomain                 -> Kernel_Utils               2
  AdDomain                 -> BillingDomain              2
  AIDomain                 -> Kernel_Utils               2
  AIDomain                 -> EventDomain                2
  AccountDomain            -> Kernel_Utils               2
  SettingDomain            -> BillingDomain              2
  SettingDomain            -> NotificationDomain         2
  EventDomain              -> SettingDomain              2
  BillingDomain            -> SupportDomain              2
  SettingDomain            -> SupportDomain              1
  AccountDomain            -> ExternalCalendarDomain     1
  AccountDomain            -> SettingDomain              1
  AdDomain                 -> SupportDomain              1
  AdDomain                 -> SettingDomain              1
  NotificationDomain       -> AccountDomain              1
  NotificationDomain       -> SupportDomain              1
  SupportDomain            -> EventDomain                1
  SupportDomain            -> AccountDomain              1
  AIDomain                 -> NotificationDomain         1
  AIDomain                 -> CalendarDomain             1

== 남은 순환 (SCC) ==
  AccountDomain <-> BillingDomain <-> EventDomain <-> ExternalCalendarDomain <-> NotificationDomain <-> SettingDomain <-> SupportDomain
     AccountDomain->ExternalCalendarDomain  Models/Account/ExternalServiceAccountinfo.swift  :: GoogleCalendarService
     AccountDomain->SettingDomain  Models/Account/UserNotificationRepository.swift  :: DeviceInfo
     ExternalCalendarDomain->AccountDomain  Repositories/Auth/ExternalServiceIntegrateRepository.swift  :: ExternalServiceAccountinfo
     ExternalCalendarDomain->AccountDomain  Repositories/Auth/ExternalServiceIntegrateRepository.swift  :: OAuth2Credential
     ExternalCalendarDomain->AccountDomain  Usecases/Account/ExternalServiceIntegration/ExternalCalendarIntegrationUsecase.swift  :: ExternalServiceAccountinfo
     ExternalCalendarDomain->AccountDomain  Usecases/Account/ExternalServiceIntegration/ExternalCalendarIntegrationUsecase.swift  :: GoogleOAuth2Credential
     ExternalCalendarDomain->AccountDomain  Usecases/Account/ExternalServiceIntegration/ExternalCalendarIntegrationUsecase.swift  :: OAuth2Credential
     ExternalCalendarDomain->AccountDomain  Usecases/Account/ExternalServiceIntegration/ExternalCalendarIntegrationUsecase.swift  :: OAuth2ServiceUsecase
     ExternalCalendarDomain->EventDomain  Models/Events/ExternalCalendar/AppleCalendarEvent.swift  :: EventTag
     ExternalCalendarDomain->EventDomain  Models/Events/ExternalCalendar/AppleCalendarEvent.swift  :: EventTagId
     ExternalCalendarDomain->EventDomain  Models/Events/ExternalCalendar/AppleCalendarEvent.swift  :: EventTime
     ExternalCalendarDomain->EventDomain  Models/Events/ExternalCalendar/AppleCalendarEventEditParams.swift  :: EventTime
     ExternalCalendarDomain->EventDomain  Models/Events/ExternalCalendar/GoogleCalendarEvent.swift  :: EventTag
     ExternalCalendarDomain->EventDomain  Models/Events/ExternalCalendar/GoogleCalendarEvent.swift  :: EventTagId
     BillingDomain->SettingDomain  Models/Billing/PaidFeatureGateFailReason.swift  :: ColorSetKeys
     BillingDomain->SettingDomain  Usecases/Billing/PaidFeatureGateUsecase.swift  :: ColorThemeLicenseRepository
     BillingDomain->SettingDomain  Usecases/Billing/PaidFeatureGateUsecase.swift  :: WidgetStyleLicenseRepository
     BillingDomain->SupportDomain  Usecases/Billing/PaidFeatureGateUsecase.swift  :: AppPolicy
     BillingDomain->SupportDomain  Usecases/Billing/PaidFeatureGateUsecase.swift  :: AppPolicyRepository
     SettingDomain->BillingDomain  Usecases/Setting/AppSettingUsecase.swift  :: PaidFeatureGateUsecase
     SettingDomain->BillingDomain  Usecases/Setting/WidgetStyleUsecase.swift  :: PaidFeatureGateUsecase
     SettingDomain->EventDomain  Models/Settings/EventSettings.swift  :: EventTagId
     SettingDomain->EventDomain  Usecases/Setting/AppSettingUsecase.swift  :: EventTag
     SettingDomain->EventDomain  Usecases/Setting/UISettingUsecase.swift  :: EventTag
     SettingDomain->SupportDomain  Models/Settings/EventSettings.swift  :: SupportMapApps
     SettingDomain->NotificationDomain  Usecases/Setting/EventNotificationSettingUsecase.swift  :: EventNotificationRepository
     SettingDomain->NotificationDomain  Usecases/Setting/EventNotificationSettingUsecase.swift  :: EventNotificationTimeOption
     EventDomain->ExternalCalendarDomain  Models/Events/EventTag.swift  :: AppleCalendar
     EventDomain->ExternalCalendarDomain  Models/Events/EventTag.swift  :: GoogleCalendar
     EventDomain->ExternalCalendarDomain  Repositories/Events/AppleCalendarRepository.swift  :: AppleCalendar
     EventDomain->ExternalCalendarDomain  Repositories/Events/AppleCalendarRepository.swift  :: EventEditParams
     EventDomain->ExternalCalendarDomain  Repositories/Events/AppleCalendarRepository.swift  :: EventEditScope
     EventDomain->ExternalCalendarDomain  Repositories/Events/AppleCalendarRepository.swift  :: EventOrigin
     EventDomain->SettingDomain  Usecases/Events/EventSyncMediator.swift  :: TemporaryUserDataMigrationUescase
     EventDomain->SettingDomain  Usecases/Events/EventTagUsecase.swift  :: DefaultEventTagColorSetting
     EventDomain->SupportDomain  Usecases/Events/DoneTodoEventsPagingUsecase.swift  :: PagingQueryType
     EventDomain->SupportDomain  Usecases/Events/DoneTodoEventsPagingUsecase.swift  :: PagingRepository
     EventDomain->SupportDomain  Usecases/Events/DoneTodoEventsPagingUsecase.swift  :: PagingResultType
     EventDomain->SupportDomain  Usecases/Events/DoneTodoEventsPagingUsecase.swift  :: PagingUsecase
     EventDomain->NotificationDomain  Models/Events/Schedule/ScheduleEvent.swift  :: EventNotificationTimeOption
     EventDomain->NotificationDomain  Models/Events/Todo/DoneTodoEvent.swift  :: EventNotificationTimeOption
     EventDomain->NotificationDomain  Models/Events/Todo/TodoEvent.swift  :: EventNotificationTimeOption
     SupportDomain->AccountDomain  Usecases/Support/FeedbackUsecase.swift  :: AccountUsecase
     SupportDomain->SettingDomain  Models/AppPolicy.swift  :: ColorThemeLicensePolicy
     SupportDomain->SettingDomain  Models/AppPolicy.swift  :: WidgetStyleLicensePolicy
     SupportDomain->SettingDomain  Usecases/Support/FeedbackUsecase.swift  :: DeviceInfo
     SupportDomain->SettingDomain  Usecases/Support/FeedbackUsecase.swift  :: FeedbackMakeParams
     SupportDomain->SettingDomain  Usecases/Support/FeedbackUsecase.swift  :: FeedbackPostMessage
     SupportDomain->SettingDomain  Usecases/Support/FeedbackUsecase.swift  :: FeedbackRepository
     SupportDomain->EventDomain  Usecases/Common/PlaceSuggestUsecase.swift  :: Place
     NotificationDomain->AccountDomain  Usecases/Notification/UserNotificationUsecase.swift  :: UserNotificationRepository
     NotificationDomain->EventDomain  Models/Notifications/EventNotification.swift  :: EventTime
     NotificationDomain->EventDomain  Models/Notifications/EventNotification.swift  :: ScheduleEvent
     NotificationDomain->EventDomain  Models/Notifications/EventNotification.swift  :: TodoEvent
     NotificationDomain->EventDomain  Usecases/Notification/EventNotificationUsecase.swift  :: ScheduleEvent
     NotificationDomain->EventDomain  Usecases/Notification/EventNotificationUsecase.swift  :: ScheduleEventUsecase
     NotificationDomain->EventDomain  Usecases/Notification/EventNotificationUsecase.swift  :: TodoEvent
     NotificationDomain->SupportDomain  Usecases/Notification/UserNotificationUsecase.swift  :: DeviceInfoFetchService

== 추출 층 (의존이 없는 쪽부터) ==
  순환이 남아 층을 낼 수 없다 — 위 SCC 부터 끊는다
```
