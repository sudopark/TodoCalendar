//
//  HolidayListViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 11/28/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class HolidayListViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var stubHolidayUsecase: StubHolidayUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.stubHolidayUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.stubHolidayUsecase = nil
    }
    
    private var currentYear: Int {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ .init(abbreviation: "KST")!
        return calendar.component(.year, from: Date())
    }
    
    private func makeUsecaseWithStubHoliday() -> HolidayListViewModelImple {
        let expect = expectation(description: "wait holiday")
        expect.assertForOverFulfill = false
        
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()
        
        let viewModel = HolidayListViewModelImple(
            holidayUsecase: self.stubHolidayUsecase,
            calendarSettingUscase: calendarSettingUsecase
        )
        viewModel.router = self.spyRouter
        
        let _ = self.waitFirstOutput(expect, for: self.stubHolidayUsecase.holidays().first()) {
            viewModel.prepare()
        }
        
        return viewModel
    }
}

extension HolidayListViewModelImpleTests {
    
    private func changeToUSA() {
        Task {
            let country = HolidaySupportCountry(code: "US", name: "USA")
            try await self.stubHolidayUsecase.selectCountry(country)
        }
    }
    
    // 현재 선택한 국가 업데이트시에 이름 업데이트
    func testViewModel_whenUpdateSelectedCountry_updateCountryName() {
        // given
        let expect = expectation(description: "현재 선택한 국가 업데이트시에 이름 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeUsecaseWithStubHoliday()
        
        // when
        let names = self.waitOutputs(expect, for: viewModel.currentCountryName) {
            
            self.changeToUSA()
        }
        
        // then
        XCTAssertEqual(names, ["Korea", "USA"])
    }
    
    // 현재 선택한 국가 업데이트시에 업데이트된 국가의 올해 공휴일 리스트 반환
    func testViewModel_whenUpdateSelectCountry_updateCurrentYearHolidayList() {
        // given
        let expect = expectation(description: "현재 선택한 국가 업데이트시에 업데이트된 국가의 올해 공휴일 리스트 반환")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeUsecaseWithStubHoliday()
        
        // when
        let holidayLists = self.waitOutputs(expect, for: viewModel.currentYearHolidays) {

            self.changeToUSA()
        }
        
        // then
        XCTAssertEqual(holidayLists.first?.first?.name, "holiday-1-KST")
        XCTAssertEqual(holidayLists.last?.first?.name, "holiday-1-US")
    }
    
    func testViewModel_routeToCountrySelect() {
        // given
        let viewModel = self.makeUsecaseWithStubHoliday()
        
        // when
        viewModel.selectCountry()
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToCountrySelect, true)
    }
}

private class SpyRouter: BaseSpyRouter, HolidayListRouting, @unchecked Sendable {
    
    var didRouteToCountrySelect: Bool?
    func routeToSelectCountry() {
        self.didRouteToCountrySelect = true
    }
}
