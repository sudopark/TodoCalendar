//
//  StubHolidayRepository.swift
//  TestDoubles
//
//  Created by sudo.park on 6/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


open class StubHolidayRepository: HolidayRepository {
    
    public init() { }
    
    public var stubCurrentCountry: HolidaySupportCountry?
    
    open func loadAvailableCountrise() async throws -> [HolidaySupportCountry] {
        return [
            .init(code: "KR", name: "Korea"),
            .init(code: "US", name: "USA")
        ]
    }
    
    open func loadLatestSelectedCountry() async throws -> HolidaySupportCountry? {
        return self.stubCurrentCountry
    }
    
    open func saveSelectedCountry(_ country: HolidaySupportCountry) async throws {
        self.stubCurrentCountry = country
    }
    
    open func loadHolidays(_ year: Int, _ countryCode: String) async throws -> [Holiday] {
        let name = self.holidayCachCleared ? "dummy-v2" : "dummy"
        return [
            .init(dateString: "\(year)", localName: "\(countryCode)", name: name)
        ]
    }
    
    public var holidayCachCleared: Bool = false
    open func clearHolidayCache() async throws {
        self.holidayCachCleared = true
    }
}
