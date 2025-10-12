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
import Extensions


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
}


// MARK: - LocaleProvider

public protocol LocaleProvider {
    func currentRegionCode() -> String?
    func currentLocaleIdentifier() -> String
    func is24HourFormat() -> Bool
}

extension Locale: LocaleProvider {
    
    public func currentRegionCode() -> String? {
        return self.region?.identifier
    }
    
    public func currentLocaleIdentifier() -> String {
        return Locale.current.identifier
    }
    
    public func is24HourFormat() -> Bool {
        let formatter = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)
        return !(formatter?.contains("a") == true)
    }
}


// MARK: - HolidayUsecaseImple

public final class HolidayUsecaseImple: HolidayUsecase {
    
    private let holidayRepository: any HolidayRepository
    private let dataStore: SharedDataStore
    private let localeProvider: any LocaleProvider
    
    public init(
        holidayRepository: any HolidayRepository,
        dataStore: SharedDataStore,
        localeProvider: any LocaleProvider
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
        if let savedCountry = try? await self.holidayRepository.loadLatestSelectedCountry() {
            return savedCountry
        }
        guard let regionCode = self.localeProvider.currentRegionCode()?.lowercased()
        else { return nil }
        
        let supportCountries = try await self.loadAvailableCountriesWithUpdateStore()
        guard let country = supportCountries.first(where: { $0.regionCode == regionCode })
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
        
        let years = self.currentPreparedHolidayYears()
        await self.refreshHolidays(for: country, years: years)
        
        self.dataStore.put(
            HolidaySupportCountry.self,
            key: ShareDataKeys.currentCountry.rawValue,
            country
        )
    }
    
    public var currentSelectedCountry: AnyPublisher<HolidaySupportCountry?, Never> {
        return self.dataStore
            .observe(HolidaySupportCountry.self, key: ShareDataKeys.currentCountry.rawValue)
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
        guard let currentCountry = self.dataStore.value(HolidaySupportCountry.self, key: ShareDataKeys.currentCountry.rawValue)
        else { return }
        
        let currentPreparedYears = self.currentPreparedHolidayYears()
        
        try await self.holidayRepository.clearHolidayCache()
        self.dataStore.delete(ShareDataKeys.holidays.rawValue)
        
        await self.refreshHolidays(for: currentCountry, years: currentPreparedYears)
    }
    
    private func refreshHolidays(
        for country: HolidaySupportCountry,
        years: [Int]
    ) async {
        
        await years.asyncForEach { [weak self] year in
            try? await self?.refreshHolidays(country, year)
        }
    }
    
    private func currentPreparedHolidayYears() -> [Int] {
        guard let currentCountry = self.dataStore.value(HolidaySupportCountry.self, key: ShareDataKeys.currentCountry.rawValue),
              let holidays = self.dataStore.value(Holidays.self, key: ShareDataKeys.holidays.rawValue),
              let holidayYearMap = holidays[currentCountry.code]
        else {
            return []
        }
        return holidayYearMap.keys.sorted()
    }
    
    public func refreshHolidays(_ year: Int) async throws {
        
        guard let currentCountry = self.dataStore.value(HolidaySupportCountry.self, key: ShareDataKeys.currentCountry.rawValue)
        else { return }
        
        try await self.refreshHolidays(currentCountry, year)
    }
    
    private func refreshHolidays(_ country: HolidaySupportCountry, _ year: Int) async throws {
        let locale = self.localeProvider.currentLocaleIdentifier()
        let holidays = try await self.holidayRepository.loadHolidays(
            year, country.code, locale
        )
        let shareKey = ShareDataKeys.holidays.rawValue
        self.dataStore.update(Holidays.self, key: shareKey) { old in
            return (old ?? [:]) |> key(country.code) %~ {
                return ($0 ?? [:]) |> key(year) .~ holidays
            }
        }
    }
    
    public func loadHolidays(_ year: Int) async throws -> [Holiday] {
        
        guard let currentCountry = self.dataStore.value(HolidaySupportCountry.self, key: ShareDataKeys.currentCountry.rawValue)
        else {
            throw RuntimeError("current country not prepared")
        }
        
        let locale = self.localeProvider.currentLocaleIdentifier()
        return try await self.holidayRepository.loadHolidays(
            year, currentCountry.code, locale
        )
    }
    
    public func holidays() -> AnyPublisher<[Int: [Holiday]], Never> {
        
        let asCountryHoliday: (HolidaySupportCountry?) -> AnyPublisher<[Int: [Holiday]], Never>?
        asCountryHoliday = { [weak self] country in
            guard let self = self else { return nil }
            guard let country else {
                return Just([:]).eraseToAnyPublisher()
            }
            return self.dataStore
                .observe(Holidays.self, key: ShareDataKeys.holidays.rawValue)
                .compactMap { $0 }
                .map { $0[country.code] ?? [:] }
                .eraseToAnyPublisher()
        }
        
        return self.currentSelectedCountry
            .compactMap(asCountryHoliday)
            .switchToLatest()
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    public func holiday(_ uuid: String) -> AnyPublisher<Holiday?, Never> {
        
        let selectHoliday: ([Int: [Holiday]]) -> Holiday? = { holidaysMap in
            return holidaysMap.flatMap { $0.value }
                .first(where: { $0.uuid == uuid })
        }
        return self.holidays()
            .map(selectHoliday)
            .eraseToAnyPublisher()
    }
}
