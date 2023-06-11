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
    
    func refreshHolidays(_ year: Int) async throws
    func holidays() -> AnyPublisher<[Int: [Holiday]], Never>
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
    
    private typealias Holidays = [String: [Int: [Holiday]]]
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
        try await self.holidayRepository.saveSelectedCountry(country)
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
        try await self.holidayRepository.saveSelectedCountry(country)
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
    
    public func refreshHolidays(_ year: Int) async throws {
        guard let currentCountry = self.dataStore.value(HolidaySupportCountry.self, key: ShareDataKeys.currentCountry.rawValue)
        else { return }
        
        let holidays = try await self.holidayRepository.loadHolidays(year, currentCountry.code, shouldIgnoreCache: false)
        let shareKey = ShareDataKeys.holidays.rawValue
        self.dataStore.update(Holidays.self, key: shareKey) { old in
            return (old ?? [:]) |> key(currentCountry.code) %~ {
                return ($0 ?? [:]) |> key(year) .~ holidays
            }
        }
    }
    
    public func holidays() -> AnyPublisher<[Int: [Holiday]], Never> {
        
        let asCountryHoliday: (HolidaySupportCountry) -> AnyPublisher<[Int: [Holiday]], Never>?
        asCountryHoliday = { [weak self] country in
            guard let self = self else { return nil }
            return self.dataStore
                .observe(Holidays.self, key: ShareDataKeys.holidays.rawValue)
                .compactMap { $0 }
                .map { $0[country.code] ?? [:] }
                .eraseToAnyPublisher()
        }
        
        return self.currentSelectedCountry
            .compactMap(asCountryHoliday)
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}
