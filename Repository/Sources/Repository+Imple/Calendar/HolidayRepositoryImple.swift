//
//  HolidayRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Domain
import Extensions
import SQLiteService


public final class HolidayRepositoryImple: HolidayRepository {
    
    private let localEnvironmentStorage: any EnvironmentStorage
    private let sqliteService: SQLiteService
    private let remoteAPI: any RemoteAPI
    
    public init(
        localEnvironmentStorage: any EnvironmentStorage,
        sqliteService: SQLiteService,
        remoteAPI: any RemoteAPI
    ) {
        self.localEnvironmentStorage = localEnvironmentStorage
        self.sqliteService = sqliteService
        self.remoteAPI = remoteAPI
    }
    
    private var selectedCountryKey: String { "user_holiday_country_v2" }
}


// MARK: - country

extension HolidayRepositoryImple {
    
    private var host: String { "https://date.nager.at/api/v3" }
    
    public func loadAvailableCountrise() async throws -> [HolidaySupportCountry] {
        let jsonData = try await self.remoteAPI.request(
            .get, HolidayAPIEndpoints.supportCountry,
            with: [:], parameters: [:]
        )
        let dtos = try HolidaySupportCountryDTO.decodeList(jsonData)
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
    
    private struct HolidaySupportCountryDTO: Codable {
        
        private enum CodingKeys: String, CodingKey {
            case code = "countryCode"
            case name
        }
        let country: HolidaySupportCountry
        
        init(country: HolidaySupportCountry) {
            self.country = country
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.country = .init(
                code: try container.decode(String.self, forKey: .code),
                name: try container.decode(String.self, forKey: .name)
            )
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.country.code, forKey: .code)
            try container.encode(self.country.name, forKey: .name)
        }
        
        static func decodeList(
            _ jsonData: Data
        ) throws -> [HolidaySupportCountryDTO] {
            
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else {
                throw RuntimeError("invalid form of json")
            }
            return json.compactMap { pair -> HolidaySupportCountryDTO? in
                guard
                    let id = pair.value as? String,
                    let localeAndCountryCode = id.components(separatedBy: "#").first,
                    let countryCode = localeAndCountryCode.components(separatedBy: ".").last
                else { return nil }
                
                return .init(country: .init(code: countryCode, name: pair.key))
            }
        }
    }
}


// MARK: - holidays

extension HolidayRepositoryImple {
    
    public func loadHolidays(_ year: Int, _ countryCode: String) async throws -> [Holiday] {
        if let cached = try? await self.loadHolidaysFromCache(year, countryCode),
           cached.isEmpty == false {
            return cached
        }
        let refreshed =  try await self.loadHolidaysFromRemote(year, countryCode)
        try? await self.updateHolidayCache(year, countryCode, refreshed)
        return refreshed
    }
    
    private func loadHolidaysFromCache(_ year: Int, _ countryCode: String) async throws -> [Holiday] {
        let query = HolidayTable.selectAll()
            .where { $0.countryCode == countryCode }
            .where { $0.year == year }
        let mappging: (CursorIterator) throws -> Holiday = { cursor in
            return try HolidayTable.Entity(cursor).holiday
        }
        return try await self.sqliteService.async.run { try $0.load(query, mapping: mappging) }
    }
    
    private func updateHolidayCache(_ year: Int, _ countryCode: String, _ holidays: [Holiday]) async throws {
        let entities: [HolidayTable.Entity] = holidays.map {
            return .init(countryCode, year, $0)
        }
        try await self.sqliteService.async.run { db in
            let deleteQuery = HolidayTable.delete()
                .where { $0.countryCode == countryCode }
                .where { $0.year == year }
            try? db.delete(HolidayTable.self, query: deleteQuery)
            
            try db.insert(HolidayTable.self, entities: entities)
        }
    }
    
    private func loadHolidaysFromRemote(_ year: Int, _ countryCode: String) async throws -> [Holiday] {
        let dtos: [HolidayDTO] = try await self.remoteAPI.request(
            .get,
            HolidayAPIEndpoints.holidays(year: year, countryCode: countryCode)
        )
        return dtos.map { $0.holiday }
    }
    
    public func clearHolidayCache() async throws {
        try await self.sqliteService.async.run { try $0.dropTable(HolidayTable.self) }
    }
    
    private struct HolidayTable: Table {
        
        enum Columns: String, TableColumn {
            case countryCode = "c_code"
            case year
            case dateString = "d_txt"
            case localName
            case name
            
            var dataType: ColumnDataType {
                switch self {
                case .countryCode: return .text([.notNull])
                case .year: return .integer([.notNull])
                case .dateString: return .text([.notNull, .unique])
                case .localName: return .text([.notNull])
                case .name: return .text([.notNull])
                }
            }
        }
        
        struct Entity: RowValueType {
            let countryCode: String
            let year: Int
            let holiday: Holiday
            
            init(_ countryCode: String, _ year: Int, _ holiday: Holiday) {
                self.countryCode = countryCode
                self.year = year
                self.holiday = holiday
            }
            
            init(_ cursor: CursorIterator) throws {
                self.countryCode = try cursor.next().unwrap()
                self.year = try cursor.next().unwrap()
                self.holiday = .init(
                    dateString: try cursor.next().unwrap(),
                    localName: try cursor.next().unwrap(),
                    name: try cursor.next().unwrap()
                )
            }
        }
        
        typealias ColumnType = Columns
        typealias EntityType = Entity
        static var tableName: String { "Holidays" }
        
        static func scalar(_ entity: Entity, for column: Columns) -> (any ScalarType)? {
            switch column {
            case .countryCode: return entity.countryCode
            case .year: return entity.year
            case .dateString: return entity.holiday.dateString
            case .localName: return entity.holiday.localName
            case .name: return entity.holiday.name
            }
        }
    }
    
    private struct HolidayDTO: Decodable {
        
        private enum CodingKeys: String, CodingKey {
            case date
            case localName
            case name
        }
        let holiday: Holiday
        
        init(holiday: Holiday) {
            self.holiday = holiday
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(holiday: .init(
                dateString: try container.decode(String.self, forKey: .date),
                localName: try container.decode(String.self, forKey: .localName),
                name: try container.decode(String.self, forKey: .name))
            )
        }
    }
}
