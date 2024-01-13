//
//  StubHolidayRepository.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/10.
//

import Foundation
import Domain


class StubHolidayRepository: HolidayRepository {
    
    var stubCurrentCountry: HolidaySupportCountry?
    
    func loadAvailableCountrise() async throws -> [HolidaySupportCountry] {
        return [
            .init(code: "KR", name: "Korea"),
            .init(code: "US", name: "USA")
        ]
    }
    
    func loadLatestSelectedCountry() async throws -> HolidaySupportCountry? {
        return self.stubCurrentCountry
    }
    
    func saveSelectedCountry(_ country: HolidaySupportCountry) async throws {
        self.stubCurrentCountry = country
    }
    
    func loadHolidays(_ year: Int, _ countryCode: String) async throws -> [Holiday] {
        let name = self.holidayCachCleared ? "dummy-v2" : "dummy"
        return [
            .init(dateString: "\(year)", localName: "\(countryCode)", name: name)
        ]
    }
    
    var holidayCachCleared: Bool = false
    func clearHolidayCache() async throws {
        self.holidayCachCleared = true
    }
}
