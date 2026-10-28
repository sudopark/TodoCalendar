# 01 — 순환 제거 (DP-1.1)

Domain 을 한 모듈로 둔 채 파일·타입만 옮겨서, 나중에 모듈로 떼어 낼 서브도메인 사이의 의존 그래프를 DAG 로 만든 단계다. 측정은 `scripts/target_graph.py` 로 한다.

## 측정 기준

- 파일 경로로 서브도메인을 정한다. `Device/`·`Migration/`·`Models/Place/` 는 일반 규칙보다 먼저 각각 `DeviceInterface`·`MigrationDomain`·`PlaceServiceInterface` 로 본다.
- 다른 서브도메인이 선언한 타입 이름이 소스에 나오면 간선 하나로 센다. 중첩 타입 이름(`Event`·`Scope`·`Subject`·`Tag`·`Constant` 등)과 `//` 주석 속 이름은 오탐이라 뺀다.
- 순환이 없으면 의존이 없는 쪽부터 추출 층을 낸다.

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
