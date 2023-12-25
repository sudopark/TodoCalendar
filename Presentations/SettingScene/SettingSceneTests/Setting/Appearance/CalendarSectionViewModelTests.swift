//
//  CalendarSectionViewModelTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 12/7/23.
//

import XCTest
import Combine
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class CalendarSectionViewModelTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
    }
    
    private var dummySetting: CalendarAppearanceSetting {
        return .init(accnetDayPolicy: [
            .sunday : true, .saturday: false, .holiday: false
        ], showUnderLineOnEventDay: true)
    }
    
    private func makeViewModel() -> CalendarSectionViewModelImple {
        
        let uiSettingUsecase = StubUISettingUsecase()
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()
        
        let viewModel = CalendarSectionViewModelImple(
            setting: self.dummySetting,
            calendarSettingUsecase: calendarSettingUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        return viewModel
    }
}


extension CalendarSectionViewModelTests {
    
    // 시작요일 변경에 따라 calendarApearanceModel 데이터 모델 구성 업데이트
    func testCalendarAppearanceModel_byStartOfWeek() {
        // given
        func parameterizeTest(
            _ startOfWeek: DayOfWeeks,
            expectWeekDays: [DayOfWeeks],
            expectDayNumbers: [[Int?]]
        ) {
            // given
            // when
            let model = CalendarAppearanceModel(startOfWeek)
            
            // then
            XCTAssertEqual(model.weekDays, expectWeekDays)
            
            let dayNumbers = model.weeks.map { w in w.map { $0?.number } }
            XCTAssertEqual(dayNumbers, expectDayNumbers)
            
            let weekEnds = model.weeks.flatMap { $0 }.filter { $0?.isWeekEnd == true }.map { $0?.number }
            XCTAssertEqual(weekEnds, [6, 7, 13, 14, 20, 21, 27, 28])
            
            let hasEvents = model.weeks.flatMap { $0 }.filter { $0?.hasEvent == true }.map { $0?.number }
            XCTAssertEqual(hasEvents, [2, 4, 5, 14, 17, 22, 23, 30])
        }
        // when + then
        parameterizeTest(
            .sunday,
            expectWeekDays: [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday],
            expectDayNumbers: [
                [nil, 1, 2, 3, 4, 5, 6],
                [7, 8, 9, 10, 11, 12, 13],
                [14, 15, 16, 17, 18, 19, 20],
                [21, 22, 23, 24, 25, 26, 27],
                [28, 29, 30, 31, nil, nil, nil]
            ]
        )
        parameterizeTest(
            .monday,
            expectWeekDays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday],
            expectDayNumbers: [
                [1, 2, 3, 4, 5, 6, 7],
                [8, 9, 10, 11, 12, 13, 14],
                [15, 16, 17, 18, 19, 20, 21],
                [22, 23, 24, 25, 26, 27, 28],
                [29, 30, 31, nil, nil, nil, nil]
            ]
        )
        parameterizeTest(
            .tuesday,
            expectWeekDays: [.tuesday, .wednesday, .thursday, .friday, .saturday, .sunday, .monday],
            expectDayNumbers: [
                [nil, nil, nil, nil, nil, nil, 1],
                [2, 3, 4, 5, 6, 7, 8],
                [9, 10, 11, 12, 13, 14, 15],
                [16, 17, 18, 19, 20, 21, 22],
                [23, 24, 25, 26, 27, 28, 29],
                [30, 31, nil, nil, nil, nil, nil]
            ]
        )
        parameterizeTest(
            .wednesday,
            expectWeekDays: [.wednesday, .thursday, .friday, .saturday, .sunday, .monday, .tuesday],
            expectDayNumbers: [
                [nil, nil, nil, nil, nil, 1, 2],
                [3, 4, 5, 6, 7, 8, 9],
                [10, 11, 12, 13, 14, 15, 16],
                [17, 18, 19, 20, 21, 22, 23],
                [24, 25, 26, 27, 28, 29, 30],
                [31, nil, nil, nil, nil, nil, nil]
            ]
        )
        parameterizeTest(
            .thursday,
            expectWeekDays: [.thursday, .friday, .saturday, .sunday, .monday, .tuesday, .wednesday],
            expectDayNumbers: [
                [nil, nil, nil, nil, 1, 2, 3],
                [4, 5, 6, 7, 8, 9, 10],
                [11, 12, 13, 14, 15, 16, 17],
                [18, 19, 20, 21, 22, 23, 24],
                [25, 26, 27, 28, 29, 30, 31]
            ]
        )
        parameterizeTest(
            .friday,
            expectWeekDays: [.friday, .saturday, .sunday, .monday, .tuesday, .wednesday, .thursday],
            expectDayNumbers: [
                [nil, nil, nil, 1, 2, 3, 4],
                [5, 6, 7, 8, 9, 10, 11],
                [12, 13, 14, 15, 16, 17, 18],
                [19, 20, 21, 22, 23, 24, 25],
                [26, 27, 28, 29, 30, 31, nil]
            ]
        )
        parameterizeTest(
            .saturday,
            expectWeekDays: [.saturday, .sunday, .monday, .tuesday, .wednesday, .thursday, .friday],
            expectDayNumbers: [
                [nil, nil, 1, 2, 3, 4, 5],
                [6, 7, 8, 9, 10, 11, 12],
                [13, 14, 15, 16, 17, 18, 19],
                [20, 21, 22, 23, 24, 25, 26],
                [27, 28, 29, 30, 31, nil, nil]
            ]
        )
    }
    
    // prepare시에 현재 시작요일 기준으로 calendarApearanceModel 반환
    func testViewModel_whenPrepare_provideCalendarAppearanceModel_andUpdate() {
        // given
        let expect = expectation(description: "prepare시에 현재 시작요일 기준으로 calendarApearanceModel 반환 및 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.calendarAppearanceModel) {
            
            viewModel.changeStartOfWeekDay(.friday)
        }
        
        // then
        let startOfWeek1 = models.first?.weekDays.first
        XCTAssertEqual(startOfWeek1, .sunday)
        
        let startOfWeek2 = models.last?.weekDays.first
        XCTAssertEqual(startOfWeek2, .friday)
    }
}

extension CalendarSectionViewModelTests {
    
    // 최초에 저장된 강조 요일 정보 반환 및 toggle
    func testViewModel_provideAccentDaysAndToggle() {
        // given
        let expect = expectation(description: "최초에 저장된 강조 요일 정보 반환 및 toggle")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let accentDaysMaps = self.waitOutputs(expect, for: viewModel.accentDaysActivatedMap) {
            
            viewModel.toggleAccentDay(.sunday)
            
            viewModel.toggleAccentDay(.holiday)
            viewModel.toggleAccentDay(.saturday)
        }
        
        // then
        XCTAssertEqual(accentDaysMaps, [
            [.holiday: false, .saturday: false, .sunday: true],
            [.holiday: false, .saturday: false, .sunday: false],
            [.holiday: true, .saturday: false, .sunday: false],
            [.holiday: true, .saturday: true, .sunday: false],
        ])
    }
    
    // 최초에 이벤트 있는날 밑줄표시 정보 반환 및 toggle
    func testViewModel_provideShowUnderlineOnEvnetDayAndToggle() {
        // given
        let expect = expectation(description: "최초에 이벤트 있는날 밑줄표시 정보 반환 및 toggle")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.isShowUnderLineOnEventDay) {
            
            viewModel.toggleIsShowUnderLineOnEventDay(false)
            viewModel.toggleIsShowUnderLineOnEventDay(true)
        }
        
        // then
        XCTAssertEqual(isOns, [true, false, true])
    }
}

extension CalendarSectionViewModelTests {
    
    // TODO: 테마 변경으로 이동
}


private class SpyRouter: BaseSpyRouter, CalendarSectionRouting, @unchecked Sendable {
    
    var didRouteToSelectColorTheme: Bool?
    func routeToSelectColorTheme() {
        self.didRouteToSelectColorTheme = true
    }
}
