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
    func saveSelectedCountry(_ code: String) async throws
    
    func loadHolidays(_ year: Int, _ countryCode: String, shouldIgnoreCache: Bool) async throws -> [Holiday]
}
