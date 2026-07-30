//
//  HolidaysFetchUsecase.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions


// MARK: - HolidaysFetchUsecase

protocol HolidaysFetchUsecase {
 
    func holidaysGivenYears(
        _ range: Range<TimeInterval>,
        timeZone: TimeZone
    ) async throws -> [Holiday]

    /// 현재 선택된 공휴일 국가 코드. 공휴일 D-day 대상 키의 국가 세그먼트에 쓴다.
    func currentCountryCode() async -> String?
}


// MARK: - HolidaysFetchUsecaseImple

actor HolidaysFetchCacheStore {
    var holidayMap: [Int: [Holiday]] = [:]
    func update(_ year: Int, _ holidays: [Holiday]) {
        self.holidayMap[year] = holidays
    }
    func reset() {
        self.holidayMap = [:]
    }
}

final class HolidaysFetchUsecaseImple: HolidaysFetchUsecase {
    
    private let holidayUsecase: any HolidayUsecase
    private let cached: HolidaysFetchCacheStore
    init(
        holidayUsecase: any HolidayUsecase,
        cached: HolidaysFetchCacheStore
    ) {
        self.holidayUsecase = holidayUsecase
        self.cached = cached
    }
}


extension HolidaysFetchUsecaseImple {
    
    func holidaysGivenYears(_ range: Range<TimeInterval>, timeZone: TimeZone) async throws -> [Holiday] {
        
        try await self.holidayUsecase.prepare()
        
        func holidays(_ year: Int) async throws -> [Holiday] {
            if let cached = await self.cached.holidayMap[year] {
                return cached
            }
            let holidays = try await self.holidayUsecase.loadHolidays(year)
            await self.cached.update(year, holidays)
            return holidays
        }
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let thisYear = calendar.component(.year, from: Date(timeIntervalSince1970: range.lowerBound))
        let holidaysInThisYear = try await holidays(thisYear)
        let yearAtUpperBound = calendar.component(.year, from: Date(timeIntervalSince1970: range.upperBound))
        
        guard thisYear != yearAtUpperBound
        else {
            return holidaysInThisYear
        }
        let holidaysInNextYear = try await holidays(yearAtUpperBound)
        return holidaysInThisYear + holidaysInNextYear
    }

    func currentCountryCode() async -> String? {
        try? await self.holidayUsecase.prepare()
        let country = await self.holidayUsecase.currentSelectedCountry
            .values.first(where: { _ in true })
        return country??.code
    }
}
