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
    
    private func makeViewModelWithStubHoliday() -> HolidayListViewModelImple {
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
    
    private func makeViewModelWithoutHolidays() -> HolidayListViewModelImple {
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()
        let viewModel = HolidayListViewModelImple(
            holidayUsecase: NoCountryStubHolidayUsecase(),
            calendarSettingUscase: calendarSettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension HolidayListViewModelImpleTests {
    
    private func changeToUSA() {
        Task {
            let country = HolidaySupportCountry(regionCode: "us", code: "US", name: "USA")
            try await self.stubHolidayUsecase.selectCountry(country)
        }
    }
    
    func testViewModel_whenSelectCountryNotExists_providePlaceHolder() {
        // given
        let expect = expectation(description: "선택된 국가정보 없으면 플레이스홀더 문구 노출")
        let viewModel = self.makeViewModelWithoutHolidays()
        
        // when
        let name = self.waitFirstOutput(expect, for: viewModel.currentCountryName) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(name, "setting.holiday.country.current::placeHolder".localized())
    }
    
    // 현재 선택한 국가 업데이트시에 이름 업데이트
    func testViewModel_whenUpdateSelectedCountry_updateCountryName() {
        // given
        let expect = expectation(description: "현재 선택한 국가 업데이트시에 이름 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithStubHoliday()
        
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
        let viewModel = self.makeViewModelWithStubHoliday()
        
        // when
        let holidayLists = self.waitOutputs(expect, for: viewModel.currentYearHolidays, timeout: 0.1) {

            self.changeToUSA()
        }
        
        // then
        XCTAssertEqual(holidayLists.first?.first?.name, "holiday-1-KST")
        XCTAssertEqual(holidayLists.last?.first?.name, "holiday-1-US")
    }
    
    func testViewModel_whenRefersh_refreshHolidayListAtGivenYear() {
        // given
        let expect = expectation(description: "공휴일 목록 갱신하면, 해당 년도의 공휴일 리스트 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithStubHoliday()
        
        // when
        let holidayLists = self.waitOutputs(expect, for: viewModel.currentYearHolidays) {
            
            viewModel.refresh()
        }
        
        // then
        XCTAssertEqual(holidayLists.count, 2)
    }
    
    func testViewModel_routeToCountrySelect() {
        // given
        let viewModel = self.makeViewModelWithStubHoliday()

        // when
        viewModel.selectCountry()

        // then
        XCTAssertEqual(self.spyRouter.didRouteToCountrySelect, true)
    }
}


// MARK: - hidden holiday

extension HolidayListViewModelImpleTests {

    // 숨긴 공휴일 이름 목록을 정렬해서 제공
    func testViewModel_provideHiddenHolidayNames_sorted() {
        // given
        let expect = expectation(description: "숨긴 공휴일 이름 목록 정렬 제공")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithStubHoliday()

        // when
        let nameLists = self.waitOutputs(expect, for: viewModel.hiddenHolidayNames) {
            Task {
                try await self.stubHolidayUsecase.hideHoliday("추석")
                try await self.stubHolidayUsecase.hideHoliday("설날")
            }
        }

        // then
        XCTAssertEqual(nameLists, [[], ["추석"], ["설날", "추석"]])
    }

    // 숨긴 공휴일 탭하면 복원 요청되어 목록에서 제거
    func testViewModel_whenShowHoliday_restoreAndRemoveFromHiddenList() {
        // given
        let expect = expectation(description: "숨김 해제 시 목록에서 제거")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithStubHoliday()

        // when
        let nameLists = self.waitOutputs(expect, for: viewModel.hiddenHolidayNames) {
            Task {
                try await self.stubHolidayUsecase.hideHoliday("추석")
                viewModel.showHoliday("추석")
            }
        }

        // then
        XCTAssertEqual(nameLists, [[], ["추석"], []])
    }

    // 숨김 처리하면 공휴일 목록(안 숨김)에서 빠지고, 해제하면 다시 추가됨
    func testViewModel_whenHideAndShowHoliday_reflectedInHolidayList() {
        // given
        let expect = expectation(description: "숨김/해제가 공휴일 목록에 반영")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithStubHoliday()
        let targetName = "holiday-1-KST"

        // when
        let holidayLists = self.waitOutputs(expect, for: viewModel.currentYearHolidays) {
            Task {
                try await self.stubHolidayUsecase.hideHoliday(targetName)
                viewModel.showHoliday(targetName)
            }
        }

        // then
        let containsTarget = holidayLists.map { items in
            items.contains { $0.name == targetName }
        }
        XCTAssertEqual(containsTarget, [true, false, true])
    }
}

private class SpyRouter: BaseSpyRouter, HolidayListRouting, @unchecked Sendable {
    
    var didRouteToCountrySelect: Bool?
    func routeToSelectCountry() {
        self.didRouteToCountrySelect = true
    }
}

private final class NoCountryStubHolidayUsecase: StubHolidayUsecase {
    
    override var currentSelectedCountry: AnyPublisher<HolidaySupportCountry?, Never> {
        return Just(nil).eraseToAnyPublisher()
    }
}
