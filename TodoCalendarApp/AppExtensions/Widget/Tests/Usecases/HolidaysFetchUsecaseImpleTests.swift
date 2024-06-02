//
//  HolidaysFetchUsecaseImpleTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 6/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles


class HolidaysFetchUsecaseImpleTests: BaseTestCase {
    
    private var spyRepository: PrivateStubHolidayRepository!
    
    override func setUpWithError() throws {
        self.spyRepository = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyRepository = nil
    }
    
    private func makeUsecase() -> HolidaysFetchUsecaseImple {
        
        self.spyRepository.stubCurrentCountry = .init(code: "KR", name: "Korea")
        let holidayUsecase = HolidayUsecaseImple(
            holidayRepository: self.spyRepository,
            dataStore: .init(),
            localeProvider: Locale.current
        )
        return .init(holidayUsecase: holidayUsecase)
    }
    
    private var kst: TimeZone { TimeZone(abbreviation: "KST")! }
    
    private var calendar: Calendar {
        return Calendar(identifier: .gregorian) |> \.timeZone .~ kst
    }
    
    private var dummySingleYearRange: Range<TimeInterval> {
        let m1 = self.calendar.dateBySetting(from: Date()) {
            $0.year = 2023; $0.month = 5; $0.day = 1
        }!
        let m30 = m1.add(days: 30)!
        return m1.timeIntervalSince1970..<m30.timeIntervalSince1970
    }
    
    private var dummyDoubleYearRanhe: Range<TimeInterval> {
        let d31 = self.calendar.dateBySetting(from: Date()) {
            $0.year = 2023; $0.month = 12; $0.day = 30
        }!
        let j10 = self.calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 1; $0.day = 10
        }!
        return d31.timeIntervalSince1970..<j10.timeIntervalSince1970
    }
}

extension HolidaysFetchUsecaseImpleTests {
    
    // 단일년도 휴일 조회 + 캐시 없음 + 캐시 있음
    func testUsecase_loadHolidaysForSingleYear() async throws {
        // given
        let usecas = self.makeUsecase()
        let range = self.dummySingleYearRange
        try await usecas.reset()
        
        // when
        let holidays1 = try await usecas.holidaysGivenYears(range, timeZone: kst)
        let holidays2 = try await usecas.holidaysGivenYears(range, timeZone: kst)
        
        // then
        XCTAssertEqual(holidays1.count, 1)
        XCTAssertEqual(holidays2.count, 1)
        XCTAssertEqual(holidays1, holidays2)
        XCTAssertEqual(self.spyRepository.loadHolidaysCallWith.count, 1)
    }
    
    // 2개 연도 휴일 조회
    func testUsecase_loadHolidaysForDoubleYear() async throws {
        // given
        let usecase = self.makeUsecase()
        let range = self.dummyDoubleYearRanhe
        try await usecase.reset()
        
        // when
        let holidays = try await usecase.holidaysGivenYears(range, timeZone: kst)
        
        // then
        XCTAssertEqual(holidays.count, 2)
        XCTAssertEqual(holidays.first?.dateString, "2023")
        XCTAssertEqual(holidays.last?.dateString, "2024")
    }
    
    // 국가 변경시 reset하고 다시 휴일 조회
    func testUsecase_whenCountryChanged_resetAndLoad() async throws {
        // given
        let usecase = self.makeUsecase()
        let range = self.dummySingleYearRange
        try await usecase.reset()
        
        // when
        let holidaysForKr = try await usecase.holidaysGivenYears(range, timeZone: kst)
        
        let us = HolidaySupportCountry(code: "US", name: "USA")
        try await self.spyRepository.saveSelectedCountry(us)
        
        try await usecase.reset()
        let holidaysForUs = try await usecase.holidaysGivenYears(range, timeZone: kst)
        
        // then
        XCTAssertEqual(holidaysForKr.first?.localName, "KR")
        XCTAssertEqual(holidaysForUs.first?.localName, "US")
    }
    
    // reset 안하고 조회 요청들어오면 에러
    func testUsecase_whenLoadHolidaysWithoutReset_error() async {
        // given
        let usecase = self.makeUsecase()
        var fail: Error?
        
        // when
        do {
            let _ = try await usecase.holidaysGivenYears(self.dummySingleYearRange, timeZone: kst)
        } catch {
            fail = error
        }
        
        // then
        XCTAssertNotNil(fail)
    }
}

private final class PrivateStubHolidayRepository: StubHolidayRepository {
    
    var loadHolidaysCallWith: [(Int, String)] = []
    override func loadHolidays(_ year: Int, _ countryCode: String) async throws -> [Holiday] {
        self.loadHolidaysCallWith.append((year, countryCode))
        return try await super.loadHolidays(year, countryCode)
    }
}
