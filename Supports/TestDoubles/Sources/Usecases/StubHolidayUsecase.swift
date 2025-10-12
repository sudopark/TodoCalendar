//
//  StubHolidayUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/06/26.
//

import Foundation
import Combine
import Domain
import Prelude
import Optics


open class StubHolidayUsecase: HolidayUsecase {
    
    public init(
        country: HolidaySupportCountry = .init(regionCode: "kr", code: "KST", name: "Korea"),
        holidays: [Int: [Holiday]]? = nil
    ) {
        self.currentSelectedCountrySubject.send(country)
        guard let holidays else { return }
        self.holidaysSubject.send([
            country.code: holidays
        ])
    }
    
    open func prepare() async throws {
        let country = HolidaySupportCountry(regionCode: "kr", code: "KST", name: "Korea")
        self.currentSelectedCountrySubject.send(country)
    }
    
    open func refreshAvailableCountries() async throws {
        let countries: [HolidaySupportCountry] = [
            .init(regionCode: "kr", code: "KST", name: "Korea"),
            .init(regionCode: "us", code: "US", name: "USA"),
            .init(regionCode: "sm", code: "Some", name: "Dummy")
        ]
        self.availableCountriesSubject.send(countries)
    }
    
    public let currentSelectedCountrySubject = CurrentValueSubject<HolidaySupportCountry?, Never>(nil)
    open func selectCountry(_ country: HolidaySupportCountry) async throws {
        let oldCountry = self.currentSelectedCountrySubject.value
        self.currentSelectedCountrySubject.send(country)
        guard let oldCountry,
              let holidays = self.holidaysSubject.value?[oldCountry.code]
        else { return }
        
        let years = holidays.keys.sorted()
        await years.asyncForEach { year in
            try? await self.refreshHolidays(year)
        }
    }
    
    open var currentSelectedCountry: AnyPublisher<HolidaySupportCountry?, Never> {
        return self.currentSelectedCountrySubject
            .eraseToAnyPublisher()
    }
    
    private let availableCountriesSubject = CurrentValueSubject<[HolidaySupportCountry]?, Never>(nil)
    open var availableCountries: AnyPublisher<[HolidaySupportCountry], Never> {
        return self.availableCountriesSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    public func refreshHolidays() async throws {
        let oldValue = self.holidaysSubject.value ?? [:]
        self.holidaysSubject.send(oldValue)
    }
    
    let holidaysSubject = CurrentValueSubject<[String: [Int: [Holiday]]]?, Never>(nil)
    
    open func refreshHolidays(_ year: Int) async throws {
        guard let country = self.currentSelectedCountrySubject.value
        else { return }
        let holidays = (1...5).map { int -> Holiday in
            return Holiday(
                uuid: "hd1",
                dateString: "\(year)-0\(int)-0\(int)",
                name: "holiday-\(int)-\(country.code)"
            )
        }
        let oldMap = self.holidaysSubject.value ?? [:]
        let newHolidays = (oldMap[country.code] ?? [:]) |> key(year) .~ holidays
        let newMap = oldMap |> key(country.code) .~ newHolidays
        self.holidaysSubject.send(newMap)
    }
    
    open func loadHolidays(_ year: Int) async throws -> [Holiday] {
        guard let country = self.currentSelectedCountrySubject.value
        else { return [] }
        let holidays = (1...5).map { int -> Holiday in
            return Holiday(
                uuid: "hd2",
                dateString: "\(year)-0\(int)-0\(int)",
                name: "holiday-\(int)-\(country.code)"
            )
        }
        return holidays
    }
    
    open func holidays() -> AnyPublisher<[Int : [Holiday]], Never> {
        
        return self.currentSelectedCountry
            .map { country in
                guard let country
                else {
                    return Just([Int:[Holiday]]()).eraseToAnyPublisher()
                }
                return self.holidaysSubject.compactMap { $0?[country.code] }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
    
    open func holiday(_ uuid: String) -> AnyPublisher<Holiday?, Never> {
        return self.holidays()
            .map { holidayMap in
                return holidayMap
                    .flatMap { $0.value }
                    .first(where: { $0.uuid == uuid })
            }
            .eraseToAnyPublisher()
    }
}
