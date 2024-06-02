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


protocol HolidaysFetchUsecase {
 
    func reset() async throws
    
    func holidaysGivenYears(
        _ range: Range<TimeInterval>,
        timeZone: TimeZone
    ) async throws -> [Holiday]
}


final class HolidaysFetchUsecaseImple: HolidaysFetchUsecase {
    
    private let holidayUsecase: any HolidayUsecase
    init(holidayUsecase: any HolidayUsecase) {
        self.holidayUsecase = holidayUsecase
    }
    
    private actor Cache {
        var holidayMap: [Int: [Holiday]] = [:]
        func update(_ year: Int, _ holidays: [Holiday]) {
            self.holidayMap[year] = holidays
        }
        func reset() {
            self.holidayMap = [:]
        }
    }
    private let cached = Cache()
}


extension HolidaysFetchUsecaseImple {
    
    func reset() async throws {
        await self.cached.reset()
        try await self.holidayUsecase.prepare()
    }
    
    func holidaysGivenYears(_ range: Range<TimeInterval>, timeZone: TimeZone) async throws -> [Holiday] {
        
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
}
