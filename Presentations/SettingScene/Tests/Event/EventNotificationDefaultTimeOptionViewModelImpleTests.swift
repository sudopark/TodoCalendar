//
//  EventNotificationDefaultTimeOptionViewModelImpleTests.swift
//  SettingScene
//
//  Created by sudo.park on 1/21/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene

class EventNotificationDefaultTimeOptionViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyEventNotificationSettingUsecase: StubEventNotificationSettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = []
        self.spyRouter = .init()
        self.spyEventNotificationSettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.spyEventNotificationSettingUsecase = nil
    }
    
    private func makeViewModel(
        isPermissionDenied: Bool = false
    ) -> EventNotificationDefaultTimeOptionViewModelImple {
        let permissionUsecase = StubNotificationPermissionUsecase()
        permissionUsecase.stubAuthorizationStatusCheckResult = isPermissionDenied
            ? .success(.denied) : .success(.authorized)
        
        let viewModel = EventNotificationDefaultTimeOptionViewModelImple(
            forAllDay: false,
            notificationPermissionUsecase: permissionUsecase,
            eventNotificationSettingUsecase: self.spyEventNotificationSettingUsecase
        )
        
        viewModel.router = self.spyRouter
        
        return viewModel
    }
}

extension EventNotificationDefaultTimeOptionViewModelImpleTests {
    
    func testViewModel_whenNotificationPermissionNotDetermined_showIsNeed() {
        // given
        func parameterizeTest(
            isDenied: Bool,
            expectIsShow: Bool
        ) {
            // given
            let expect = expectation(description: "notification 허가 여부에 따라 필요함을 알림")
            let viewModel = self.makeViewModel(isPermissionDenied: isDenied)
            
            // when
            let isNeedMessage = self.waitFirstOutput(expect, for: viewModel.isNeedNotificationPermission) {
                viewModel.reload()
            } ?? nil
            
            // then
            XCTAssertEqual(isNeedMessage, expectIsShow)
        }
        
        // when + then
        parameterizeTest(isDenied: true, expectIsShow: true)
        parameterizeTest(isDenied: false, expectIsShow: false)
    }
    
    func testViewModel_whenPermissionDeniedAndRequestPermission_openSystemSetting() {
        // given
        let expect = expectation(description: "권한 거부된경우 + 요청시 시스템 설정 오픈")
        let viewModel = self.makeViewModel(isPermissionDenied: true)
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.isNeedNotificationPermission) {
            viewModel.reload()
        }
        viewModel.requestPermission()
        
        // then
        XCTAssertEqual(self.spyRouter.didOpenSystemNotificationSetting, true)
    }
}

extension EventNotificationDefaultTimeOptionViewModelImpleTests {
    
    // load options
    func testViewModel_loadOptions() {
        // given
        let expect = expectation(description: "선택가능 옵션 로드")
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.options) {
            viewModel.reload()
        }
        
        // then
        let options = models?.map { $0.option }
        XCTAssertEqual(options, [nil] + self.spyEventNotificationSettingUsecase.availableTimes(forAllDay: false))
    }

    private func makeViewModelWithLoadOptions() -> EventNotificationDefaultTimeOptionViewModelImple {
        // given
        let expect = expectation(description: "wait-options")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.options) {
            viewModel.reload()
        }
        
        // then
        return viewModel
    }
    
    func testViewModel_updateSelectDefaultOption() {
        // given
        let expect = expectation(description: "선택옵션 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithLoadOptions()
        
        // when
        let selecteds = self.waitOutputs(expect, for: viewModel.selectedOption) {
            
            viewModel.selectOption(.atTime)
            
            viewModel.selectOption(nil)
        }
        
        // then
        XCTAssertEqual(selecteds, [nil, .atTime, nil])
    }
    
    func testViewModel_whenUpdateSelectOption_saveOption() {
        // given
        let viewModel = self.makeViewModelWithLoadOptions()
        
        // when
        viewModel.selectOption(.atTime)
        
        // then
        let savedOption = self.spyEventNotificationSettingUsecase.loadDefailtNotificationTimeOption(forAllDay: false)
        XCTAssertEqual(savedOption, .atTime)
    }
}


private final class SpyRouter: BaseSpyRouter, EventNotificationDefaultTimeOptionRouting, @unchecked Sendable {
    
    var didOpenSystemNotificationSetting: Bool?
    func openSystemNotificationSetting() {
        self.didOpenSystemNotificationSetting = true
    }
}
