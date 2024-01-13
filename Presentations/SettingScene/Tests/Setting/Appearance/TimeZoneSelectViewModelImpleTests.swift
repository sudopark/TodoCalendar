//
//  TimeZoneSelectViewModelImpleTests.swift
//  SettingScene
//
//  Created by sudo.park on 12/25/23.
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


class TimeZoneSelectViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var stubUsecase: StubUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.stubUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.stubUsecase = nil
    }
    
    private func makeViewModel(
        startWithSelectSystemTimeZone: Bool = true
    ) -> TimeZoneSelectViewModelImple {
        if startWithSelectSystemTimeZone {
            let timeZone = TimeZone.current
            self.stubUsecase.selectTimeZone(timeZone)
        } else {
            let timeZone = TimeZone(identifier: "Africa/Abidjan")!
            self.stubUsecase.selectTimeZone(timeZone)
        }
        let viewModel = TimeZoneSelectViewModelImple(
            calendarSettingUsecase: self.stubUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}


extension TimeZoneSelectViewModelImpleTests {
    
    // 타임존 리스트 제공
    func testViewModel_provideTimeZoneList() {
        // given
        let expect = expectation(description: "타임존 리스트 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let list = self.waitFirstOutput(expect, for: viewModel.timeZoneModels) {
            viewModel.loadList()
        }
        
        // then
        let system = TimeZone.current
        XCTAssertEqual(list?.systemTimeZone.identifier, system.identifier)
        XCTAssertEqual(list?.timeZones.count, 3)
    }
    
    func testViewModel_provideSelectedTimeZoneIdentifier() {
        // given
        func parameterizeTest(_ isSystem: Bool, expectIdentifier: String) {
            // given
            let expect = expectation(description: "선택된 타임존의 식별자 제공")
            expect.assertForOverFulfill = false
            let viewModel = self.makeViewModel(startWithSelectSystemTimeZone: isSystem)
            
            // when
            let identifier = self.waitFirstOutput(expect, for: viewModel.selectedTimeZoneIdentifier)
            
            // then
            XCTAssertEqual(identifier, expectIdentifier)
        }
        // when + then
        parameterizeTest(true, expectIdentifier: TimeZone.current.identifier)
        parameterizeTest(false, expectIdentifier: "Africa/Abidjan")
    }
    
    // 검색시 매칭되는 리스트 반환
    func testViewModel_whenSearch_filterMatchingTimeZone() {
        // given
        let expect = expectation(description: "검색시 매칭되는 리스트 반환")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let lists = self.waitOutputs(expect, for: viewModel.timeZoneModels) {
            viewModel.loadList()
            
            viewModel.search(keyword: "Africa")
            viewModel.search(keyword: "wrong")
            viewModel.search(keyword: "")
        }
        
        // then
        let notSystemTimeZoneCounts = lists.map { $0.timeZones.count }
        XCTAssertEqual(notSystemTimeZoneCounts, [3, 1, 0, 3])
    }
    
    // 선택시 선택 타임존 업데이트하고 화면 이탈
    func testViewModel_whenAfterSelectTimeZone_updateAndCloseScene() {
        // given
        let expect = expectation(description: "타임존 선택시 선택 타임존 업데이트하고 화면 이탈")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let timeZones = self.waitOutputs(expect, for: self.stubUsecase.currentTimeZone) {
            viewModel.loadList()
            
            viewModel.selectTimeZone("America/Cayman")
        }
        
        // then
        let identifiers = timeZones.map { $0.identifier }
        XCTAssertEqual(identifiers, [TimeZone.current.identifier, "America/Cayman"])
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
}


private class SpyRouter: BaseSpyRouter, TimeZoneSelectRouting, @unchecked Sendable { }

private class StubUsecase: StubCalendarSettingUsecase {
    
    override func loadAllTimeZones() -> [TimeZone] {
        var timeZones = super.loadAllTimeZones()
        let systemTimeZone = TimeZone.current
        if !timeZones.contains(systemTimeZone) {
            timeZones.append(systemTimeZone)
        }
        return timeZones
    }
}
