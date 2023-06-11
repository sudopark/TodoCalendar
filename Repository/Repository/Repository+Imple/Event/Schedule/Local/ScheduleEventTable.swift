//
//  ScheduleEventTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import SQLiteService
import Domain
import Extensions


struct ScheduleEventTable: Table {
    
    enum Columns: String, TableColumn {
        case uuid
        case name
        case eventTagId = "tag_id"
        case repeatTimezone = "repeat_timezone"
        case repeatingStart = "repeating_start"
        case repeatingOption = "repeating_option"
        case repeatingEnd = "repeating_end"
        case showTurn = "show_turn"
        case excludeTimes = "exclude_times"
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .eventTagId: return .text([])
            case .repeatTimezone: return .text([])
            case .repeatingStart: return .real([])
            case .repeatingOption: return .text([])
            case .repeatingEnd: return .real([])
            case .showTurn: return .integer([.notNull, .default(0)])
            case .excludeTimes: return .text([])
            }
        }
    }
    
    struct Entity: RowValueType {
        let uuid: String
        let name: String
        var eventTagId: String?
        var repeating: EventRepeating?
        let showTurn: Bool
        var excludeTimes: [String] = []
        
        init(_ event: ScheduleEvent) {
            self.uuid = event.uuid
            self.name = event.name
            self.eventTagId = event.eventTagId
            self.repeating = event.repeating
            self.showTurn = event.showTurn
            self.excludeTimes = Array(event.repeatingTimeToExcludes)
        }
        
        init(_ cursor: CursorIterator) throws {
            self.uuid = try cursor.next().unwrap()
            self.name = try cursor.next().unwrap()
            self.eventTagId = cursor.next()
            
            let timeZoneAbbre: String? = cursor.next()
            let start: Double? = cursor.next()
            let optionText: String? = cursor.next()
            let end: Double? = cursor.next()
            self.showTurn = try cursor.next().unwrap()
            let excludeTimesStr: String? = cursor.next()
            self.excludeTimes = excludeTimesStr?.data(using: .utf8)
                .flatMap { try? JSONDecoder().decode([String].self, from: $0) }
                ?? []
            
            let optionMapper = optionText?.data(using: .utf8)
                .flatMap { try? JSONDecoder().decode(EventRepeatingOptionCodableMapper.self, from: $0) }
            guard let option = optionMapper?.option else { return }
            guard let timeZone = timeZoneAbbre,
                  let startInterval = start
            else {
                throw RuntimeError("invalid event repeating option")
            }
            self.repeating = .init(
                repeatingStartTime: .init(startInterval, timeZone: timeZone),
                repeatOption: option)
            self.repeating?.repeatingEndTime = end.map { TimeStamp($0, timeZone: timeZone) }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = Entity
    static var tableName: String { "Schedules" }
    
    static func scalar(_ entity: EntityType, for column: Columns) -> ScalarType? {
        switch column {
        case .uuid: return entity.uuid
        case .name: return entity.name
        case .eventTagId: return entity.eventTagId
        case .repeatTimezone: return entity.repeating?.repeatingStartTime.timeZoneAbbreviation
        case .repeatingStart: return entity.repeating?.repeatingStartTime.utcTimeInterval
        case .repeatingOption: return entity.repeating
                .map { EventRepeatingOptionCodableMapper(option: $0.repeatOption) }
                .flatMap { try? JSONEncoder().encode($0) }
                .flatMap { String(data: $0, encoding: .utf8) }
        case .repeatingEnd: return entity.repeating?.repeatingEndTime?.utcTimeInterval
        case .showTurn: return entity.showTurn
        case .excludeTimes: return (try? JSONEncoder().encode(entity.excludeTimes))
                .flatMap { String(data: $0, encoding: .utf8) }
        }
    }
}
