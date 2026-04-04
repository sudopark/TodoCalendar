//
//  EventSettingViewModelImpleTests.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene

class EventSettingViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var stubSettingUsecase: StubEventSettingUsecase!
    private var stubEventNotificationSettingUsecase: StubEventNotificationSettingUsecase!
    private var stubExternalCalednarUsecase: StubExternalCalendarIntegrationUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.stubSettingUsecase = .init()
        self.stubEventNotificationSettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.stubSettingUsecase = nil
        self.stubEventNotificationSettingUsecase = nil
        self.stubExternalCalednarUsecase = nil
    }
    
    private func makeViewModel(
        isLogin: Bool = true,
        accounts: [ExternalServiceAccountinfo] = [],
        integrateError: (any Error)? = nil
    ) -> EventSettingViewModelImple {
        let tagUsecase = StubEventTagUsecase()
        let externalUsecase: StubExternalCalendarIntegrationUsecase
        if let integrateError {
            let errorStub = StubExternalCalendarIntegrationUsecaseWithError(accounts)
            errorStub.stubIntegrateError = integrateError
            externalUsecase = errorStub
        } else {
            externalUsecase = StubExternalCalendarIntegrationUsecase(accounts)
        }
        self.stubExternalCalednarUsecase = externalUsecase
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.selectTimeZone(TimeZone(abbreviation: "KST")!)
        
        let viewModel = EventSettingViewModelImple(
            eventSettingUsecase: self.stubSettingUsecase,
            eventNotificationSettingUsecase: self.stubEventNotificationSettingUsecase,
            eventTagUsecase: tagUsecase,
            supportExternalCalendarServices: [
                GoogleCalendarService(scopes: [.readOnly]),
                AppleCalendarService()
            ],
            externalCalendarServiceUsecase: externalUsecase,
            accountUsecase: StubAccountUsecase(isLogin ? .init("some") : nil),
            eventSyncUsecase: StubEventSyncUsecase(),
            calendarSettingUsecase: calendarSettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension EventSettingViewModelImpleTests {
    
    // 선택된 태그 정보 반환
    func testViewModel_provideCurrentNewDefaultTag() {
        // given
        let expect = expectation(description: "선택된 태그 정보 반환")
        let viewModel = self.makeViewModel()
        
        // when
        let model = self.waitFirstOutput(expect, for: viewModel.selectedTagModel) { 
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(model?.id, .default)
        XCTAssertEqual(model?.name, "eventTag.defaults.default::name".localized())
    }
    
    // 태그 선택화면으로 이동 및 업데이트
    func testViewModel_changeNewDefaultTagSetting() {
        // given
        let expect = expectation(description: "태그 선택화면으로 이동 및 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.selectedTagModel) {
            viewModel.prepare()
            
            viewModel.selectTag()
            
            let params = EditEventSettingsParams() |> \.defaultNewEventTagId .~ .custom("some")
            _ = try! self.stubSettingUsecase.changeEventSetting(params)
        }
        
        // then
        let ids = models.map { $0.id }
        XCTAssertEqual(ids, [.default, .custom("some")])
        XCTAssertEqual(self.spyRouter.didRouteToSelectTag, true)
    }
    
    // 선택된 기간정보 반환
    func testViewModel_provideSelectedNewEventDefaultPeriod() {
        // given
        let expect = expectation(description: "선택된 기간정보 반환")
        let viewModel = self.makeViewModel()
        
        // when
        let period = self.waitFirstOutput(expect, for: viewModel.selectedPeriod) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(period?.period, .minute0)
    }
    
    // 기간 업데이트
    func testViewModel_updateSelectedNewEventDefaultPeriod() {
        // given
        let expect = expectation(description: "기간 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let periods = self.waitOutputs(expect, for: viewModel.selectedPeriod) {
            viewModel.prepare()
            
            viewModel.selectPeriod(.minute10)
        }
        
        // then
        XCTAssertEqual(periods.map { $0.period }, [.minute0, .minute10])
    }
}

extension EventSettingViewModelImpleTests {
    
    private func changeOption(
        _ viewModel: EventSettingViewModelImple,
        forAllDay: Bool,
        _ newValue: EventNotificationTimeOption?
    ) {
        viewModel.selectEventNotificationTimeOption(forAllDay: forAllDay)
        self.stubEventNotificationSettingUsecase.saveDefaultNotificationTimeOption(
            forAllDay: forAllDay,
            option: newValue
        )
        viewModel.reloadEventNotificationSetting()
    }
    
    // eventNotificationTime text for not allday
    func testViewModel_provideCurrentEventNotificationTimeOptionText() {
        // given
        let expect = expectation(description: "설정된 기본 이벤트 알림 옵션 제공")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let texts = self.waitOutputs(expect, for: viewModel.selectedEventNotificationTimeText) {
            viewModel.reloadEventNotificationSetting()
            
            self.changeOption(viewModel, forAllDay: false, .atTime)
            
            self.changeOption(viewModel, forAllDay: false, nil)
        }
        
        // then
        XCTAssertEqual(texts, [
            "event_notification_setting::option_title::no_notification".localized(),
            "event_notification_setting::option_title::at_time".localized(),
            "event_notification_setting::option_title::no_notification".localized(),
        ])
        XCTAssertEqual(self.spyRouter.didRouteToEventNotificationTimeForAllDays, [false, false])
    }
    
    // eventNotificationTime text for allday
    func testViewModel_provideCurrentAllDayEventNotificationTimeOptionText() {
        // given
        let expect = expectation(description: "설정된 기본 allDay 이벤트 알림 옵션 제공")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let texts = self.waitOutputs(expect, for: viewModel.selectedAllDayEventNotificationTimeText) {
            viewModel.reloadEventNotificationSetting()
            
            self.changeOption(viewModel, forAllDay: true, .allDay9AM)
            
            self.changeOption(viewModel, forAllDay: true, .allDay12AM)
            
            self.changeOption(viewModel, forAllDay: true, nil)
        }
        
        // then
        XCTAssertEqual(texts, [
            "event_notification_setting::option_title::no_notification".localized(),
            "event_notification_setting::option_title::allday_9am".localized(),
            "event_notification_setting::option_title::allday_12pm".localized(),
            "event_notification_setting::option_title::no_notification".localized(),
        ])
        XCTAssertEqual(self.spyRouter.didRouteToEventNotificationTimeForAllDays, [true, true, true])
    }
    
    func testViewModel_provideDefaultMapApp() {
        // given
        let expect = expectation(description: "기본 지도앱 정보 제공")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let maps = self.waitOutputs(expect, for: viewModel.defaultMapApp) {
            viewModel.prepare()
            
            let params = EditEventSettingsParams() |> \.defaultMappApp .~ .apple
            _ = try? self.stubSettingUsecase.changeEventSetting(params)
        }
        
        // then
        XCTAssertEqual(maps, [nil, .apple])
    }
}

// MARK: - event sync

extension EventSettingViewModelImpleTests {
    
    // 로그아웃 - event sync model nil
    func testViewModel_whenNotLogin_syncModelIsNil() {
        // given
        let expect = expectation(description: "로그아웃 - event sync model nil")
        let viewModel = self.makeViewModel(isLogin: false)
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.eventSyncModel) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(models, [nil])
    }
    
    // 로그인 - read to sync -> sync -> read to sync
    func testViewModel_whenLogin_forceEventSync() {
        // given
        let expect = expectation(description: "로그인 - read to sync -> sync -> read to sync")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(isLogin: true)
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.eventSyncModel, timeout: 0.1) {
            viewModel.prepare()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                viewModel.forceSync()
            }
        }
        
        // then
        XCTAssertEqual(models, [
            .readToSync(lastSyncDataTime: "01/01/1970 10:00"),
            .syncInProgress,
            .readToSync(lastSyncDataTime: "01/01/1970 11:00")
        ])
    }
}

// MARK: - external calendar

extension EventSettingViewModelImpleTests {
    
    func testViewModel_whenHasExternalCalendarAccount_provideExternalCalendarServiceModel() {
        // given
        let expect = expectation(description: "외부 캘린더 연동된경우 정보 제공")
        let service = GoogleCalendarService(scopes: [.readOnly])
        let account = ExternalServiceAccountinfo(service.identifier, email: "email")
        let viewModel = self.makeViewModel(accounts: [account])
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.integratedExternalCalendars) {
            viewModel.prepare()
        }
        
        // then
        let appleService = AppleCalendarService()
        XCTAssertEqual(models, [
            ExternalCalanserServiceModel(service, accountId: account.email)!,
            ExternalCalanserServiceModel(service, accountId: nil)!,
            ExternalCalanserServiceModel(appleService, accountId: nil)!
        ])
    }
    
    // 외부서비스 연동
    func testViewModel_connect_externalCalendar() {
        // given
        let expect = expectation(description: "외부서비스 연동")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isConnectings = self.waitOutputs(expect, for: viewModel.isConnectOrDisconnectExternalCalednar) {
            
            let service = GoogleCalendarService(scopes: [.readOnly])
            viewModel.connectExternalCalendar(service.identifier)
        }
        
        // then
        XCTAssertEqual(isConnectings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "event_setting::external_calendar::start::message".localized())
    }
    
    // 외부서비스 연동 해제
    func testViewModel_disconnect_externalCalendar() {
        // given
        let expect = expectation(description: "외부서비스 연동 해제")
        expect.expectedFulfillmentCount = 3
        let service = GoogleCalendarService(scopes: [.readOnly])
        let account = ExternalServiceAccountinfo(service.identifier, email: "email")
        let viewModel = self.makeViewModel(accounts: [account])
        
        // when
        let isConnectings = self.waitOutputs(expect, for: viewModel.isConnectOrDisconnectExternalCalednar, timeout: 0.1) {
            viewModel.disconnectExternalCalendar(service.identifier, accountId: account.email!)
        }
        
        // then
        XCTAssertEqual(isConnectings, [false, true, false])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage, "event_setting::external_calendar::stop::message".localized())
    }
    
    // 외부 서비스 연동 여부에 따라 연동정보 업데이트
    func testViewModel_whenExternalCalendarConnectionChanged_updateServiceModels() {
        // given
        let expect = expectation(description: "외부서비스 연동 여부에 따라 연동정보 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        let service = GoogleCalendarService(scopes: [.readOnly])

        // when
        let modelLists = self.waitOutputs(expect, for: viewModel.integratedExternalCalendars, timeout: 0.5) {

            viewModel.connectExternalCalendar(service.identifier)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.disconnectExternalCalendar(service.identifier, accountId: "email")
            }
        }

        // then
        let appleNotIntegrated = ExternalCalanserServiceModel(AppleCalendarService(), accountId: nil)!
        XCTAssertEqual(modelLists, [
            [.init(service, accountId: nil)!, appleNotIntegrated],
            [.init(service, accountId: "email")!, .init(service, accountId: nil)!, appleNotIntegrated],
            [.init(service, accountId: nil)!, appleNotIntegrated]
        ])
    }

    // 다중 계정 연동 시 계정별 row + notIntegrated row 제공
    func testViewModel_whenMultipleAccountsIntegrated_provideRowsPerAccount() {
        // given
        let expect = expectation(description: "다중 계정 연동 시 계정별 row + notIntegrated row 제공")
        let service = GoogleCalendarService(scopes: [.readOnly])
        let account1 = ExternalServiceAccountinfo(service.identifier, email: "email1")
        let account2 = ExternalServiceAccountinfo(service.identifier, email: "email2")
        let viewModel = self.makeViewModel(accounts: [account1, account2])

        // when
        let models = self.waitFirstOutput(expect, for: viewModel.integratedExternalCalendars) {
            viewModel.prepare()
        }

        // then
        XCTAssertEqual(models, [
            .init(service, accountId: "email1")!,
            .init(service, accountId: "email2")!,
            .init(service, accountId: nil)!,
            ExternalCalanserServiceModel(AppleCalendarService(), accountId: nil)!
        ])
    }

    // Apple Calendar 서비스 모델도 함께 제공
    func testViewModel_provideAppleCalendarServiceModel() {
        // given
        let expect = expectation(description: "Apple Calendar 서비스 모델 제공")
        let viewModel = self.makeViewModel()

        // when
        let models = self.waitFirstOutput(expect, for: viewModel.integratedExternalCalendars) {
            viewModel.prepare()
        }

        // then
        let appleModels = models?.filter { $0.serviceId == AppleCalendarService.id }
        XCTAssertEqual(appleModels?.count, 1)
        XCTAssertEqual(appleModels?.first?.status, .notIntegrated)
        XCTAssertEqual(appleModels?.first?.serviceName, "event_setting::external_calendar::apple::serviceName".localized())
    }

    // Apple Calendar 연동 시 서비스 모델 업데이트
    func testViewModel_whenAppleCalendarConnected_updateServiceModel() {
        // given
        let expect = expectation(description: "Apple Calendar 연동 시 서비스 모델 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()

        // when
        let modelLists = self.waitOutputs(expect, for: viewModel.integratedExternalCalendars, timeout: 0.5) {
            viewModel.connectExternalCalendar(AppleCalendarService.id)
        }

        // then
        let lastAppleModels = modelLists.last?.filter { $0.serviceId == AppleCalendarService.id }
        XCTAssertEqual(lastAppleModels?.count, 1)
        XCTAssertEqual(lastAppleModels?.first?.status, .integrated(accountId: "email"))
    }

    // 다중 계정 중 하나만 해제 시 나머지 계정 유지
    func testViewModel_whenDisconnectOneOfMultipleAccounts_remainingAccountsStay() {
        // given
        let expect = expectation(description: "다중 계정 중 하나만 해제 시 나머지 계정 유지")
        expect.expectedFulfillmentCount = 2
        let service = GoogleCalendarService(scopes: [.readOnly])
        let account1 = ExternalServiceAccountinfo(service.identifier, email: "email1")
        let account2 = ExternalServiceAccountinfo(service.identifier, email: "email2")
        let viewModel = self.makeViewModel(accounts: [account1, account2])

        // when
        let modelLists = self.waitOutputs(expect, for: viewModel.integratedExternalCalendars, timeout: 0.1) {
            viewModel.disconnectExternalCalendar(service.identifier, accountId: "email1")
        }

        // then
        XCTAssertEqual(modelLists.last, [
            .init(service, accountId: "email2")!,
            .init(service, accountId: nil)!,
            ExternalCalanserServiceModel(AppleCalendarService(), accountId: nil)!
        ])
    }

    // Apple Calendar 권한 거부 시 설정 이동 confirm dialog 노출
    func testViewModel_whenAppleCalendarPermissionDenied_showConfirmDialogWithSettingsOption() {
        // given
        let expect = expectation(description: "권한 거부 시 설정 이동 confirm dialog 노출")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(integrateError: AppleCalendarPermissionFailReason.denied)
        self.spyRouter.shouldConfirmNotCancel = true

        // when
        let _ = self.waitOutputs(expect, for: viewModel.isConnectOrDisconnectExternalCalednar, timeout: 0.5) {
            viewModel.connectExternalCalendar(AppleCalendarService.id)
        }

        // then
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
        XCTAssertEqual(self.spyRouter.didOpenSystemSetting, true)
    }

    // Apple Calendar 기기 제한 시 지원 불가 dialog 노출
    func testViewModel_whenAppleCalendarPermissionRestricted_showInformationalDialog() {
        // given
        let expect = expectation(description: "기기 제한 시 지원 불가 dialog 노출")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(integrateError: AppleCalendarPermissionFailReason.restricted)

        // when
        let _ = self.waitOutputs(expect, for: viewModel.isConnectOrDisconnectExternalCalednar, timeout: 0.5) {
            viewModel.connectExternalCalendar(AppleCalendarService.id)
        }

        // then
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
        XCTAssertEqual(self.spyRouter.didShowConfirmWith?.withCancel, false)
        XCTAssertNil(self.spyRouter.didOpenSystemSetting)
    }

    // Apple Calendar writeOnly 시 설정 이동 confirm dialog 노출
    func testViewModel_whenAppleCalendarPermissionWriteOnly_showConfirmDialogWithSettingsOption() {
        // given
        let expect = expectation(description: "writeOnly 시 설정 이동 confirm dialog 노출")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(integrateError: AppleCalendarPermissionFailReason.writeOnly)
        self.spyRouter.shouldConfirmNotCancel = true

        // when
        let _ = self.waitOutputs(expect, for: viewModel.isConnectOrDisconnectExternalCalednar, timeout: 0.5) {
            viewModel.connectExternalCalendar(AppleCalendarService.id)
        }

        // then
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
        XCTAssertEqual(self.spyRouter.didOpenSystemSetting, true)
    }

    // 구글+애플 동시 연동 후 애플만 해제
    func testViewModel_whenGoogleAndAppleConnected_disconnectApple() {
        // given
        let expect = expectation(description: "구글+애플 동시 연동 후 애플만 해제")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        let googleService = GoogleCalendarService(scopes: [.readOnly])

        // when
        let modelLists = self.waitOutputs(expect, for: viewModel.integratedExternalCalendars, timeout: 1.0) {
            viewModel.connectExternalCalendar(googleService.identifier)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                viewModel.connectExternalCalendar(AppleCalendarService.id)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.disconnectExternalCalendar(AppleCalendarService.id, accountId: "email")
            }
        }

        // then
        let last = modelLists.last
        let googleModels = last?.filter { $0.serviceId == GoogleCalendarService.id }
        let appleModels = last?.filter { $0.serviceId == AppleCalendarService.id }
        XCTAssertEqual(googleModels?.count, 2)
        XCTAssertEqual(googleModels?.first?.status, .integrated(accountId: "email"))
        XCTAssertEqual(appleModels?.count, 1)
        XCTAssertEqual(appleModels?.first?.status, .notIntegrated)
    }
}

private final class StubExternalCalendarIntegrationUsecaseWithError: StubExternalCalendarIntegrationUsecase {

    var stubIntegrateError: (any Error)?

    override func integrate(external service: any ExternalCalendarService) async throws -> ExternalServiceAccountinfo {
        if let error = stubIntegrateError { throw error }
        return try await super.integrate(external: service)
    }
}


private class SpyRouter: BaseSpyRouter, EventSettingRouting, @unchecked Sendable {

    var didRouteToSelectTag: Bool?
    func routeToSelectTag() {
        self.didRouteToSelectTag = true
    }

    var didRouteToEventNotificationTimeForAllDays: [Bool] = []
    func routeToEventNotificationTime(forAllDay: Bool) {
        self.didRouteToEventNotificationTimeForAllDays.append(forAllDay)
    }

    var didRouteToSelectDefaultMapApp: Bool?
    func routeToSelectDefaultMapApp() {
        self.didRouteToSelectDefaultMapApp = true
    }

    var didOpenSystemSetting: Bool?
    func openSystemSetting() {
        self.didOpenSystemSetting = true
    }
}
