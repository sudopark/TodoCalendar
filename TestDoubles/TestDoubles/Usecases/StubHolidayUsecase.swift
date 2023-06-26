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
        country: HolidaySupportCountry = .init(code: "KST", name: "Korea"),
        holidays: [Int: [Holiday]]? = nil
    ) {
        self.currentSelectedCountrySubject.send(country)
        guard let holidays else { return }
        self.holidaysSubject.send([
            country.code: holidays
        ])
    }
    
    open func prepare() async throws {
        let country = HolidaySupportCountry(code: "KST", name: "Korea")
        self.currentSelectedCountrySubject.send(country)
    }
    
    open func refreshAvailableCountries() async throws {
        let countries: [HolidaySupportCountry] = [
            .init(code: "KST", name: "Korea"),
            .init(code: "US", name: "USA"),
            .init(code: "Some", name: "Dummy")
        ]
        self.availableCountriesSubject.send(countries)
    }
    
    private let currentSelectedCountrySubject = CurrentValueSubject<HolidaySupportCountry?, Never>(nil)
    open func selectCountry(_ country: HolidaySupportCountry) async throws {
        self.currentSelectedCountrySubject.send(country)
    }
    
    open var currentSelectedCountry: AnyPublisher<HolidaySupportCountry, Never> {
        return self.currentSelectedCountrySubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    private let availableCountriesSubject = CurrentValueSubject<[HolidaySupportCountry]?, Never>(nil)
    open var availableCountries: AnyPublisher<[HolidaySupportCountry], Never> {
        return self.availableCountriesSubject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    let holidaysSubject = CurrentValueSubject<[String: [Int: [Holiday]]]?, Never>(nil)
    open func refreshHolidays(_ year: Int) async throws {
        guard let country = self.currentSelectedCountrySubject.value
        else { return }
        let holidays = (0..<5).map { int -> Holiday in
            return Holiday(dateString: "\(year)-0\(int)-0\(int)", localName: "h:\(int)", name: "holiday-\(int)")
        }
        let oldMap = self.holidaysSubject.value ?? [:]
        let newHolidays = (oldMap[country.code] ?? [:]) |> key(year) .~ holidays
        let newMap = oldMap |> key(country.code) .~ newHolidays
        self.holidaysSubject.send(newMap)
    }
    
    open func holidays() -> AnyPublisher<[Int : [Holiday]], Never> {
        
        return self.currentSelectedCountry
            .compactMap { country in
                return self.holidaysSubject.compactMap { $0?[country.code] }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}
