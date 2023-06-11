//
//  HolidayRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Domain
import Extensions


public final class HolidayRepositoryImple: HolidayRepository {
    
    private let localEnvironmentStorage: EnvironmentStorage
    private let remoteAPI: RemoteAPI
    
    public init(
        localEnvironmentStorage: EnvironmentStorage,
        remoteAPI: RemoteAPI
    ) {
        self.localEnvironmentStorage = localEnvironmentStorage
        self.remoteAPI = remoteAPI
    }
    
    private var selectedCountryKey: String { "user_holiday_country" }
}

extension HolidayRepositoryImple {
    
    public func loadAvailableCountrise() async throws -> [HolidaySupportCountry] {
        let dtos: [HolidaySupportCountryDTO] = try await self.remoteAPI.request(
            .get,
            path: "https://date.nager.at/api/v3/AvailableCountries"
        )
        return dtos.map { $0.country }
    }
    
    public func loadLatestSelectedCountry() async throws -> HolidaySupportCountry? {
        let dto: HolidaySupportCountryDTO? = self.localEnvironmentStorage.load(self.selectedCountryKey)
        return dto?.country
    }
    
    public func saveSelectedCountry(_ country: HolidaySupportCountry) async throws {
        let dto = HolidaySupportCountryDTO(country: country)
        self.localEnvironmentStorage.update(self.selectedCountryKey, dto)
    }
    
    public func loadHolidays(_ year: Int, _ countryCode: String, shouldIgnoreCache: Bool) async throws -> [Holiday] {
        throw RuntimeError("not implemented")
    }
}


private extension HolidayRepositoryImple {
    
    struct HolidaySupportCountryDTO: Codable {
        
        private enum CodingKeys: String, CodingKey {
            case code = "countryCode"
            case name
        }
        let country: HolidaySupportCountry
        
        init(country: HolidaySupportCountry) {
            self.country = country
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.country = .init(
                code: try container.decode(String.self, forKey: .code),
                name: try container.decode(String.self, forKey: .name)
            )
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.country.code, forKey: .code)
            try container.encode(self.country.name, forKey: .name)
        }
    }
}
