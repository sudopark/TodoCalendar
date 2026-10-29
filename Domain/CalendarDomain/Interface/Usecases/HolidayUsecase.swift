//
//  HolidayUsecase.swift
//  CalendarDomainInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - HolidayUsecase

public protocol HolidayUsecase {
    
    func prepare() async throws
    
    func refreshAvailableCountries() async throws
    func selectCountry(_ country: HolidaySupportCountry) async throws
    
    var currentSelectedCountry: AnyPublisher<HolidaySupportCountry?, Never> { get }
    var availableCountries: AnyPublisher<[HolidaySupportCountry], Never> { get }
    
    func refreshHolidays() async throws
    func refreshHolidays(_ year: Int) async throws
    func loadHolidays(_ year: Int) async throws -> [Holiday]
    func holidays() -> AnyPublisher<[Int: [Holiday]], Never>
    func holiday(_ uuid: String) -> AnyPublisher<Holiday?, Never>

    func hideHoliday(_ name: String) async throws
    func showHoliday(_ name: String) async throws
    func hiddenHolidayNames() -> AnyPublisher<Set<String>, Never>
}
