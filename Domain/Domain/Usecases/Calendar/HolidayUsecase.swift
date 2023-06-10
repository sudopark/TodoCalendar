//
//  HolidayUsecase.swift
//  Domain
//
//  Created by sudo.park on 2023/06/10.
//

import Foundation
import Combine
import Prelude
import Optics


// MARK: - HolidayUsecase

public protocol HolidayUsecase {
    
    func prepare() async throws
    
    func refreshAvailableCountries() async throws
    func selectCountry(_ country: HolidaySupportCountry) async throws
    
    var currentSelectedCountry: AnyPublisher<HolidaySupportCountry, Never> { get }
    var availableCountries: AnyPublisher<[HolidaySupportCountry], Never> { get }
    
    func refreshHolidays() async throws
    func holidays(year: Int, countryCode: String) -> AnyPublisher<[Holiday], Never>
}


// MARK: - LocaleProvider

public protocol LocaleProvider {
    func currentRegionCode() -> String?
}

extension Locale: LocaleProvider {
    
    public func currentRegionCode() -> String? {
        return self.region?.identifier
    }
}


// MARK: - HolidayUsecaseImple

public final class HolidayUsecaseImple: HolidayUsecase {
    
    private let holidayRepository: HolidayRepository
    private let dataStore: SharedDataStore
    private let localeProvider: LocaleProvider
    
    public init(
        holidayRepository: HolidayRepository,
        dataStore: SharedDataStore,
        localeProvider: LocaleProvider
    ) {
        self.holidayRepository = holidayRepository
        self.dataStore = dataStore
        self.localeProvider = localeProvider
    }
}


// MARK: - selectable country

extension HolidayUsecaseImple {
    
    public func prepare() async throws {

        guard let country = try await self.loadLatestSelectedCountryOrDefaultValueByCurrentLocale()
        else {
            return
        }
        
        self.dataStore.put(
            HolidaySupportCountry.self,
            key: ShareDataKeys.currentCountry.rawValue,
            country
        )
    }
    
    private func loadLatestSelectedCountryOrDefaultValueByCurrentLocale() async throws -> HolidaySupportCountry? {
        guard let regionCode = self.localeProvider.currentRegionCode()?.uppercased()
        else { return nil }
        
        let supportCountries = try await self.loadAvailableCountriesWithUpdateStore()
        guard let country = supportCountries.first(where: { $0.code == regionCode })
        else {
            return nil
        }
        try await self.holidayRepository.saveSelectedCountry(country.code)
        return country
    }
    
    private func loadAvailableCountriesWithUpdateStore() async throws -> [HolidaySupportCountry] {
        let countries = try await self.holidayRepository.loadAvailableCountrise()
        self.dataStore.put(
            [HolidaySupportCountry].self,
            key: ShareDataKeys.availableCountries.rawValue,
            countries
        )
        return countries
    }
    
    public func refreshAvailableCountries() async throws {
        _ = try await self.loadAvailableCountriesWithUpdateStore()
    }
    
    public func selectCountry(_ country: HolidaySupportCountry) async throws {
        try await self.holidayRepository.saveSelectedCountry(country.code)
        self.dataStore.put(
            HolidaySupportCountry.self,
            key: ShareDataKeys.currentCountry.rawValue,
            country
        )
    }
    
    public var currentSelectedCountry: AnyPublisher<HolidaySupportCountry, Never> {
        return self.dataStore
            .observe(HolidaySupportCountry.self, key: ShareDataKeys.currentCountry.rawValue)
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public var availableCountries: AnyPublisher<[HolidaySupportCountry], Never> {
        return self.dataStore
            .observe([HolidaySupportCountry].self, key: ShareDataKeys.availableCountries.rawValue)
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}


extension HolidayUsecaseImple {
    
    public func refreshHolidays() async throws {
        
    }
    
    public func holidays(year: Int, countryCode: String) -> AnyPublisher<[Holiday], Never> {
        return Empty().eraseToAnyPublisher()
    }
}
