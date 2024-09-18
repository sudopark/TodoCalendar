//
//  TodayWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 6/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes
import UnitTestHelpKit
import TestDoubles


class TodayWidgetViewModelProviderTests: BaseTestCase {
    
    private func makeProvider(
        withoutCustomTimeZone: Bool = true,
        todayIsHoliday: Bool = false,
        withoutEvent: Bool = false
    ) -> TodayWidgetViewModelProvider {
        
        let fetchUsecase = StubCalendarEventsFetchUescase()
        fetchUsecase.hasHoliday = todayIsHoliday
        fetchUsecase.withoutAnyEvents = withoutEvent
        
        let repository = StubCalendarSettingRepository()
        if !withoutCustomTimeZone {
            repository.saveTimeZone(self.gmt)
        }
        
        return TodayWidgetViewModelProvider(
            eventsFetchusecase: fetchUsecase,
            calednarSettingRepository: repository
        )
    }
    
    private var gmt: TimeZone {
        return TimeZone(secondsFromGMT: 0)!
    }
    
    private var dummyDate: Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ gmt
        return calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 6; $0.day = 12; $0.hour = 0
        }!
    }
}

extension TodayWidgetViewModelProviderTests {
    
    func testProvider_provideViewModel() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let viewModel = try await provider.getTodayViewModel(for: self.dummyDate)
        
        // then
        XCTAssertEqual(viewModel.weekDayText, "WEDNESDAY")
        XCTAssertEqual(viewModel.day, 12)
        XCTAssertEqual(viewModel.monthAndYearText, "JUN 2024")
        XCTAssertEqual(viewModel.holidayName, nil)
        XCTAssertEqual(viewModel.isHoliday, false)
        XCTAssertEqual(viewModel.timeZoneText, nil)
        XCTAssertEqual(viewModel.totalEventCount, 4)
        XCTAssertEqual(viewModel.todoEventCount, 3)
        XCTAssertEqual(viewModel.scheduleEventcount, 1)
    }
    
    func testProvider_provideViewModel_withCustomTimeZone() async throws {
        // given
        let provider = self.makeProvider(withoutCustomTimeZone: false)
        
        // when
        let viewModel = try await provider.getTodayViewModel(for: self.dummyDate)
        
        // then
        XCTAssertEqual(viewModel.timeZoneText, "GMT")
    }
    
    func testProvider_whenTodayIsHoliday_provideViewModel() async throws {
        // given
        let provider = self.makeProvider(todayIsHoliday: true)
        
        // when
        let viewModel = try await provider.getTodayViewModel(for: self.dummyDate)
        
        // then
        XCTAssertEqual(viewModel.holidayName, "holiday")
        XCTAssertEqual(viewModel.isHoliday, true)
    }
    
    func testProvider_whenTodayEventIsEmpty_provideViewModel() async throws {
        // given
        func parameterizeTest(isHoliday: Bool) async throws {
            // given
            let provider = self.makeProvider(todayIsHoliday: isHoliday, withoutEvent: true)
            
            // when
            let viewModel = try await provider.getTodayViewModel(for: self.dummyDate)
            
            // then
            XCTAssertEqual(viewModel.totalEventCount, 0)
            XCTAssertEqual(viewModel.todoEventCount, 0)
            XCTAssertEqual(viewModel.scheduleEventcount, 0)
        }
        // when + then
        try await parameterizeTest(isHoliday: false)
        try await parameterizeTest(isHoliday: true)
    }
}
