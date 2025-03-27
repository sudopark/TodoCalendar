//
//  HolidayRepository.swift
//  Domain
//
//  Created by sudo.park on 2023/06/10.
//

import Foundation


public protocol HolidayRepository {
    
    func loadAvailableCountrise() async throws -> [HolidaySupportCountry]
    func loadLatestSelectedCountry() async throws -> HolidaySupportCountry?
    func saveSelectedCountry(_ country: HolidaySupportCountry) async throws
    
    func loadHolidays(
        _ year: Int, _ countryCode: String, _ locale: String
    ) async throws -> [Holiday]
    func clearHolidayCache() async throws
}
