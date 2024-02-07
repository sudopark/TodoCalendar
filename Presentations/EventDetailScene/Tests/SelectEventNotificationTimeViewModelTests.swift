//
//  SelectEventNotificationTimeViewModelTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 2/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


class SelectEventNotificationTimeViewModelTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyListener: SpyListener!
    private var stubUsecase: StubEventNotificationSettingUsecase!
    private var spyNotificationPermissionUsecase: StubNotificationPermissionUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.spyListener = .init()
        self.stubUsecase = .init()
        self.spyNotificationPermissionUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.spyListener = nil
        self.stubUsecase = nil
        self.spyNotificationPermissionUsecase = nil
    }
    
    private var dummyCustomOption1: EventNotificationTimeOption {
        return .custom(
            .init(year: 2023, month: 12, day: 12, hour: 2, minute: 20, second: 0)
        )
    }
    
    private var dummyCustomOption2: EventNotificationTimeOption {
        return .custom(
            .init(year: 2022, month: 12, day: 12, hour: 2, minute: 20, second: 0)
        )
    }
    
    private func makeViewModel(
        startWith: [EventNotificationTimeOption]
    ) -> SelectEventNotificationTimeViewModelImple {
        
        let viewModel = SelectEventNotificationTimeViewModelImple(
            isForAllDay: false,
            startWith: startWith,
            eventTimeComponents: .init(),
            eventNotificationSettingUsecase: self.stubUsecase,
            notificationPermissionUsecase: self.spyNotificationPermissionUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }
}


extension SelectEventNotificationTimeViewModelTests {
    
    // 최초 로드시에 디폴트 목록 제공
    func testViewModel_whenPrepare_provideDefaultOptionList() {
        // given
        let expect = expectation(description: "최초 로드시에 디폴트 목록 제공")
        let viewModel = self.makeViewModel(startWith: [])
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.defaultTimeOptions) {
            viewModel.prepare()
        }
        
        // then
        let options = models?.map { $0.option }
        XCTAssertEqual(options, self.stubUsecase.availableTimes(forAllDay: false))
    }
    
    // 최초 로드시에 디폴트 목록 중 선택된 항목 제공
    func testViewModel_whenPrepare_providePreviousSelectedDefaultOptions() {
        // given
        let expect = expectation(description: "최초 로드시에 디폴트 목록 중 선택된 항목 제공")
        let viewModel = self.makeViewModel(startWith: [
            .atTime, .before(seconds: 120)
        ])
        
        // when
        let options = self.waitFirstOutput(expect, for: viewModel.selectedDefaultTimeOptions) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(options, [.atTime, .before(seconds: 120)])
    }
    
    // 디폴트 항목 토글
    func testViewModel_toggleDefaultOptionSelected() {
        // given
        let expect = expectation(description: "디폴트 항목 토글")
        expect.expectedFulfillmentCount = 6
        let viewModel = self.makeViewModel(startWith: [])
        
        // when
        let options = self.waitOutputs(expect, for: viewModel.selectedDefaultTimeOptions) {
            viewModel.prepare()
            viewModel.toggleSelectDefaultOption(.atTime)
            viewModel.toggleSelectDefaultOption(.before(seconds: 60))
            viewModel.toggleSelectDefaultOption(.atTime)
            viewModel.toggleSelectDefaultOption(nil)
            viewModel.toggleSelectDefaultOption(nil)    // ignore
            viewModel.toggleSelectDefaultOption(.atTime)
        }
        
        // then
        XCTAssertEqual(options, [
            [],
            [.atTime],
            [.atTime, .before(seconds: 60)],
            [.before(seconds: 60)],
            [],
            [.atTime]
        ])
    }
    
    // 최초 로드시에 커스텀 항목 제공
    func testViewModel_whenPrepare_provideCustomOptions() {
        // given
        let expect = expectation(description: "최초 로드시에 커스텀 항목 제공")
        let viewModel = self.makeViewModel(startWith: [self.dummyCustomOption1])
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.customTimeOptions) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(models?.map { $0.option }, [
            self.dummyCustomOption1
        ])
    }
    
    // 커스텀 항목 추가 및 제거
    func testViewModel_addCustomOptionsAndRemove() {
        // given
        let expect = expectation(description: "커스텀 항목 추가 및 제거")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel(startWith: [])
        
        // when
        let modelsList = self.waitOutputs(expect, for: viewModel.customTimeOptions) {
            viewModel.prepare()
            
            viewModel.addCustomTimeOption(self.dummyCustomOption1.customOptionDateComponents!)
            viewModel.addCustomTimeOption(self.dummyCustomOption2.customOptionDateComponents!)
            viewModel.removeCustomTimeOption(self.dummyCustomOption1.customOptionDateComponents!)
        }
        
        // then
        XCTAssertEqual(modelsList.map { $0.count }, [
            0, 1, 2, 1
        ])
    }
    
    // 선택옵션 변경시에 listener로 변경사항 전파
    func testViewModel_whenSelectOptionChanged_notifyByListener() {
        // given
        let expect = expectation(description: "선택옵션 변경시에 listener로 변경사항 전파")
        expect.expectedFulfillmentCount = 6
        let viewModel = self.makeViewModel(startWith: [])
        self.spyListener.didSelectEventNotificationTimeUpdated = { expect.fulfill() }
        
        // when
        viewModel.toggleSelectDefaultOption(.atTime)
        viewModel.toggleSelectDefaultOption(.before(seconds: 60))
        viewModel.toggleSelectDefaultOption(.atTime)
        viewModel.addCustomTimeOption(self.dummyCustomOption1.customOptionDateComponents!)
        viewModel.addCustomTimeOption(self.dummyCustomOption2.customOptionDateComponents!)
        viewModel.toggleSelectDefaultOption(nil)
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyListener.didSelectedEventNotificationTimes, [
            [.atTime],
            [.atTime, .before(seconds: 60)],
            [.before(seconds: 60)],
            [.before(seconds: 60), self.dummyCustomOption1],
            [.before(seconds: 60), self.dummyCustomOption1, self.dummyCustomOption2],
            [self.dummyCustomOption1, self.dummyCustomOption2]
        ])
    }
}

extension SelectEventNotificationTimeViewModelTests {
    
    // 이벤트 세팅화면으로 이동
    func testViewModel_routeToEventSetting() {
        // given
        let viewModel = self.makeViewModel(startWith: [])
        
        // when
        viewModel.moveEventSetting()
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToEventSetting, true)
    }
}

// MARK: - test notification permission

extension SelectEventNotificationTimeViewModelTests {
    
    private func makeViewModelWithNotificationPermission(
        status: NotificationAuthorizationStatus,
        willAccept: Bool = true
    ) -> SelectEventNotificationTimeViewModelImple {
        self.spyNotificationPermissionUsecase.stubAuthorizationStatusCheckResult = .success(status)
        self.spyNotificationPermissionUsecase.stubRequestPermissionResult = .success(willAccept)
        return self.makeViewModel(startWith: [])
    }
    
    // 화면 진입 이후에 알림권한 아직 요청 안했으면 요청
    func testViewModel_whenNotificationPermissionNotDeterminded_requestPermission() {
        // given
        let expect = expectation(description: "화면 진입 이후에 알림권한 아직 요청 안했으면 요청")
        let viewModel = self.makeViewModelWithNotificationPermission(
            status: .notDetermined,
            willAccept: true
        )
        var newStatus: NotificationAuthorizationStatus?
        self.spyNotificationPermissionUsecase.didPermissionChanged = {
            newStatus = $0
            expect.fulfill()
        }
        
        // when
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(newStatus, .authorized)
    }
    
    // 화면 진입 이후에 알림권한 거절되었으면 설정화면으로 연결
    func testViewModel_whenNotificationPermissionDeniedAfterRequest_showIsNeedPermission() {
        // given
        let expect = expectation(description: "화면 진입 이후에 알림권한 요청하고 거절되었으면 설정화면으로 연결 유도")
        let viewModel = self.makeViewModelWithNotificationPermission(
            status: .notDetermined, 
            willAccept: false
        )
        
        // when
        let isNeed: Void? = self.waitFirstOutput(expect, for: viewModel.isNeedNotificaitonPermission) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertNotNil(isNeed)
    }
    
    func testViewModel_whenNotificationPermissionDenied_showIsNeedPermission() {
        // given
        let expect = expectation(description: "화면 진입 이후에 이미 알림권한 거절되었으면 설정화면으로 연결 유도")
        let viewModel = self.makeViewModelWithNotificationPermission(
            status: .denied
        )
        
        // when
        let isNeed: Void? = self.waitFirstOutput(expect, for: viewModel.isNeedNotificaitonPermission) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertNotNil(isNeed)
    }
    
    // 설정화면으로 이동
    func testViewModel_whenNotificationPermissionDenied_routeToSystemSetting() {
        // given
        let expect = expectation(description: "화면 진입 이후에 이미 알림권한 거절되었으면 설정화면으로 연결 유도 + 설정화면으로 이동")
        let viewModel = self.makeViewModelWithNotificationPermission(
            status: .denied
        )
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.isNeedNotificaitonPermission) {
            viewModel.prepare()
        }
        viewModel.moveSystemNotificationSetting()
        
        // then
        XCTAssertEqual(self.spyRouter.didOpenSystemNotificationSetting, true)
    }
}


private class SpyRouter: BaseSpyRouter, SelectEventNotificationTimeRouting, @unchecked Sendable {
    
    var didRouteToEventSetting: Bool?
    func routeToEventSetting() {
        self.didRouteToEventSetting = true
    }
    
    var didOpenSystemNotificationSetting: Bool?
    func openSystemNotificationSetting() {
        self.didOpenSystemNotificationSetting = true
    }
}

private class SpyListener: SelectEventNotificationTimeSceneListener {
    
    var didSelectEventNotificationTimeUpdated: (() -> Void)?
    var didSelectedEventNotificationTimes: [[EventNotificationTimeOption]] = []
    func selectEventNotificationTime(
        didUpdate selectedTimeOptions: [EventNotificationTimeOption]
    ) {
        self.didSelectedEventNotificationTimes.append(selectedTimeOptions)
        self.didSelectEventNotificationTimeUpdated?()
    }
}
