//
//  MainViewModelImpleTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 2023/08/27.
//

import XCTest
import Combine
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import TodoCalendarApp


class MainViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    private var spyRouter: SpyRouter!
    private var spyUISettingUsecase: StubUISettingUsecase!
    private var stubMigrationUsecase: StubTemporaryUserDataMigrationUescase!
    private var spyEventNotificationUsecase: SpyEventNotificationUsecase!
    private var stubEventTagUsecase: StubEventTagUsecase!
    private var stubEventNotifyService: SharedEventNotifyService!
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.spyRouter = .init()
        self.spyUISettingUsecase = .init()
        self.stubMigrationUsecase = .init()
        self.spyEventNotificationUsecase = .init()
        self.stubEventTagUsecase = .init()
        self.stubEventNotifyService = .init(notifyQueue: nil)
        self.cancelBag = .init()
        self.timeout = 0.01
    }
    
    override func tearDownWithError() throws {
        self.spyRouter = nil
        self.spyUISettingUsecase = nil
        self.stubMigrationUsecase = nil
        self.spyEventNotificationUsecase = nil
        self.stubEventTagUsecase = nil
        self.stubEventNotifyService = nil
        self.cancelBag = nil
    }
    
    private func makeViewModel(
        shouldFailMigration: Bool = false
    ) -> MainViewModelImple {
        self.stubMigrationUsecase.shouldFail = shouldFailMigration
        let expect = expectation(description: "wait until attached")
        let viewModel = MainViewModelImple(
            uiSettingUsecase: self.spyUISettingUsecase,
            temporaryUserDataMigrationUsecase: self.stubMigrationUsecase,
            eventNotificationUsecase: self.spyEventNotificationUsecase,
            eventTagUsecase: self.stubEventTagUsecase,
            eventNotifyService: self.stubEventNotifyService
        )
        viewModel.router = self.spyRouter
        self.spyRouter.didCalendarAttached = {
            expect.fulfill()
        }
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        return viewModel
    }
}

extension MainViewModelImpleTests {
    
    private func makeViewModelWithoutPrepare() -> MainViewModelImple {
        let viewModel = MainViewModelImple(
            uiSettingUsecase: self.spyUISettingUsecase,
            temporaryUserDataMigrationUsecase: self.stubMigrationUsecase,
            eventNotificationUsecase: self.spyEventNotificationUsecase,
            eventTagUsecase: self.stubEventTagUsecase,
            eventNotifyService: self.stubEventNotifyService
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
    
    func testViewModel_whenPrepare_refreshViewAppearance() {
        // given
        let expect = expectation(description: "prepare시에 viewApeparance refresh")
        let viewModel = self.makeViewModelWithoutPrepare()
        
        // when
        let setting = self.waitFirstOutput(expect, for: self.spyUISettingUsecase.currentCalendarUISeting) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testViewModel_whenPrepare_runSyncEventNotifications() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()
        
        // when
        viewModel.prepare()
        
        // then
        XCTAssertEqual(self.spyEventNotificationUsecase.didRunSync, true)
    }
    
    func testViewModel_whenPrepare_runApplyEventTagColor() {
        // given
        let expect = expectation(description: "앱 시작이후 전체 이벤트 태그 컬러 색상 정보 bind")
        let viewModel = self.makeViewModelWithoutPrepare()
        self.spyUISettingUsecase.didAppluEventTagColorCallback = { expect.fulfill() }
        
        // when
        viewModel.prepare()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_whenFocusChanged_updateCurrentMonth() {
        // given
        let expect = expectation(description: "update current month")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let months = self.waitOutputs(expect, for: viewModel.currentMonth) {
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 08), isCurrentDay: true)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentDay: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 10), isCurrentDay: false)
        }
        
        // then
        XCTAssertEqual(months, ["AUG", "SEP", "OCT"])
    }
    
    func testViewModle_whenFocusChanged_updateIsShowReturnToToday() {
        // given
        let expect = expectation(description: "update is show today")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let isShow = self.waitOutputs(expect, for: viewModel.isShowReturnToToday) {
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 08), isCurrentDay: true)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentDay: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 10), isCurrentDay: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentDay: false)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 08), isCurrentDay: true)
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 08), isCurrentDay: false)
        }
        
        // then
        XCTAssertEqual(isShow, [false, true, false, true])
    }
    
    // request return to today
    func testViewModel_requestReturnToToday() {
        // given
        let expect = expectation(description: "wait-return to today show")
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.isShowReturnToToday) {
            viewModel.calendarScene(focusChangedTo: .init(year: 2023, month: 09), isCurrentDay: false)
        }
        viewModel.returnToToday()
        
        // then
        XCTAssertEqual(self.spyRouter.interactor.didFocusMovedToToday, true)
    }
     
    func testViewModel_rouetToEventTypeSettingScene() {
        // given
        let expect = expectation(description: "이벤트 타입 세팅 화면으로 이동")
        let viewModel = self.makeViewModel()
        self.spyRouter.didRouteToEventTypeFilterSetting = {
            expect.fulfill()
        }
        
        // when
        viewModel.moveToEventTypeFilterSetting()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_routeToSettingScene() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.moveToSetting()
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToSetting, true)
    }
}

extension MainViewModelImpleTests {
    
    // show migration is need
    func testViewModel_checkIsNeedMigration() {
        // given
        let expect = expectation(description: "show migration is need")
        let viewModel = self.makeViewModel()
        
        // when
        let status = self.waitFirstOutput(expect, for: viewModel.temporaryUserDataMigrationStatus)
        
        // then
        XCTAssertEqual(status, .need(100))
    }
    
    // success
    func testViewModel_migrationSuccess() {
        // given
        let expect = expectation(description: "migration success")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let statuses = self.waitOutputs(expect, for: viewModel.temporaryUserDataMigrationStatus) {
            viewModel.handleMigration()
        }
        
        // then
        XCTAssertEqual(statuses, [.need(100), .migrating, nil])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage != nil, true)
    }
    
    // fail
    func testViewModel_migrationFailed() {
        // given
        let expect = expectation(description: "migration failed")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel(shouldFailMigration: true)
        
        // when
        let statuses = self.waitOutputs(expect, for: viewModel.temporaryUserDataMigrationStatus) {
            viewModel.handleMigration()
        }
        
        // then
        XCTAssertEqual(statuses, [.need(100), .migrating, nil, .need(10)])
        XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
    }
}

extension MainViewModelImpleTests {
    
    func testViewModel_notifyRefreshingCalendarEvent() {
        // given
        func parameterizeTest(
            _ event: RefreshingEvent,
            expectIsLoading: Bool?
        ) {
            // given
            let expect = expectation(description: "캘린더 이벤트 갱신중임을 알림")
            expect.isInverted = expectIsLoading == nil
            expect.assertForOverFulfill = false
            let viewModel = self.makeViewModel()
            
            // when
            let isLoading = self.waitFirstOutput(expect, for: viewModel.isLoadingCalendarEvents) {
                
                self.stubEventNotifyService.notify(event)
            }
            
            // then
            XCTAssertEqual(isLoading, expectIsLoading)
        }
        // when + then
        parameterizeTest(.refreshingTodo(true), expectIsLoading: true)
        parameterizeTest(.refreshingTodo(false), expectIsLoading: false)
        parameterizeTest(.refreshingSchedule(true), expectIsLoading: true)
        parameterizeTest(.refreshingSchedule(false), expectIsLoading: false)
        parameterizeTest(.refreshForemostEvent(true), expectIsLoading: true)
        parameterizeTest(.refreshForemostEvent(false), expectIsLoading: false)
        parameterizeTest(.refreshingCurrentTodo(true), expectIsLoading: true)
        parameterizeTest(.refreshingCurrentTodo(false), expectIsLoading: false)
        parameterizeTest(.refreshingUncompletedTodo(true), expectIsLoading: true)
        parameterizeTest(.refreshingUncompletedTodo(false), expectIsLoading: false)
    }
}

extension MainViewModelImpleTests {
    
    private class SpyRouter: BaseSpyRouter, MainRouting, @unchecked Sendable {
        
        var interactor = SpyCalendarInteractor()
        var didCalendarAttached: (() -> Void)?
        func attachCalendar() -> (any CalendarSceneInteractor)? {
            self.didCalendarAttached?()
            return self.interactor
        }
        
        var didRouteToEventTypeFilterSetting: (() -> Void)?
        func routeToEventTypeFilterSetting() {
            self.didRouteToEventTypeFilterSetting?()
        }
        
        var didRouteToSetting: Bool?
        func routeToSettingScene() {
            self.didRouteToSetting = true
        }
    }
    
    private class SpyCalendarInteractor: CalendarSceneInteractor, @unchecked Sendable {
        
        var didFocusMovedToToday: Bool?
        func moveFocusToToday() {
            self.didFocusMovedToToday = true
        }
    }
    
    private final class SpyEventNotificationUsecase: EventNotificationUsecase, @unchecked Sendable {
        
        var didRunSync: Bool = false
        func runSyncEventNotification() {
            self.didRunSync = true
        }
    }
}
