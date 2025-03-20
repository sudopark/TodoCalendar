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
        accounts: [ExternalServiceAccountinfo] = []
    ) -> EventSettingViewModelImple {
        let tagUsecase = StubEventTagUsecase()
        let externalUsecase = StubExternalCalendarIntegrationUsecase(accounts)
        self.stubExternalCalednarUsecase = externalUsecase
        let viewModel = EventSettingViewModelImple(
            eventSettingUsecase: self.stubSettingUsecase,
            eventNotificationSettingUsecase: self.stubEventNotificationSettingUsecase,
            eventTagUsecase: tagUsecase,
            supportExternalCalendarServices: [
                GoogleCalendarService(scopes: [.readOnly])
            ],
            externalCalendarServiceUsecase: externalUsecase
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
        XCTAssertEqual(models, [
            ExternalCalanserServiceModel(service, with: account)!
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
            viewModel.disconnectExternalCalendar(service.identifier)
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
                viewModel.disconnectExternalCalendar(service.identifier)
            }
        }
        
        // then
        XCTAssertEqual(modelLists, [
            [.init(service, with: nil)!],
            [.init(service, with: .init(service.identifier, email: "email"))!],
            [.init(service, with: nil)!]
        ])
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
}
