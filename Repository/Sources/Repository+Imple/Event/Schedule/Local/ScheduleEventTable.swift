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
        case repeatingStart = "repeating_start"
        case repeatingOption = "repeating_option"
        case repeatingEnd = "repeating_end"
        case showTurn = "show_turn"
        case excludeTimes = "exclude_times"
        case notificationOptions = "notification_options"
        case repeatingEndCount = "repeating_count"
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .eventTagId: return .text([])
            case .repeatingStart: return .real([])
            case .repeatingOption: return .text([])
            case .repeatingEnd: return .real([])
            case .showTurn: return .integer([.notNull, .default(0)])
            case .excludeTimes: return .text([])
            case .notificationOptions: return .text([])
            case .repeatingEndCount: return .integer([])
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
        var notificationOptions: [EventNotificationTimeOption] = []
        
        init(_ event: ScheduleEvent) {
            self.uuid = event.uuid
            self.name = event.name
            self.eventTagId = event.eventTagId?.stringValue
            self.repeating = event.repeating
            self.showTurn = event.showTurn
            self.excludeTimes = Array(event.repeatingTimeToExcludes)
            self.notificationOptions = event.notificationOptions
        }
        
        init(_ cursor: CursorIterator) throws {
            self.uuid = try cursor.next().unwrap()
            self.name = try cursor.next().unwrap()
            self.eventTagId = cursor.next()
            
            let start: Double? = cursor.next()
            let optionText: String? = cursor.next()
            let end: Double? = cursor.next()
            self.showTurn = try cursor.next().unwrap()
            let excludeTimesStr: String? = cursor.next()
            self.excludeTimes = excludeTimesStr?.data(using: .utf8)
                .flatMap { try? JSONDecoder().decode([String].self, from: $0) }
                ?? []
            let notificationOptionsText: String? = cursor.next()
            let endCount: Int? = cursor.next()
            
            let notificationOptionsMappers = notificationOptionsText?.data(using: .utf8)
                .flatMap {
                    try? JSONDecoder().decode([EventNotificationTimeOptionMapper].self, from: $0)
                }
            self.notificationOptions = notificationOptionsMappers?.map { $0.option } ?? []
            
            let optionMapper = optionText?.data(using: .utf8)
                .flatMap { try? JSONDecoder().decode(EventRepeatingOptionCodableMapper.self, from: $0) }
            guard let option = optionMapper?.option else { return }
            guard let startInterval = start
            else {
                throw RuntimeError("invalid event repeating option")
            }
            self.repeating = .init(
                repeatingStartTime: startInterval,
                repeatOption: option
            )
            if let end {
                self.repeating?.repeatingEndOption = .until(end)
            } else if let endCount {
                self.repeating?.repeatingEndOption = .count(endCount)
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = Entity
    static var tableName: String { "Schedules" }
    
    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 0:
            return Self.addColumnStatement(.repeatingEndCount)
        default: return nil
        }
    }
    
    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .uuid: return entity.uuid
        case .name: return entity.name
        case .eventTagId: return entity.eventTagId
        case .repeatingStart: return entity.repeating?.repeatingStartTime
        case .repeatingOption: return entity.repeating
                .map { EventRepeatingOptionCodableMapper(option: $0.repeatOption) }
                .flatMap { try? JSONEncoder().encode($0) }
                .flatMap { String(data: $0, encoding: .utf8) }
        case .repeatingEnd: return entity.repeating?.repeatingEndOption?.endTime
        case .showTurn: return entity.showTurn
        case .excludeTimes: return (try? JSONEncoder().encode(entity.excludeTimes))
                .flatMap { String(data: $0, encoding: .utf8) }
        case .notificationOptions:
            let mappers = entity.notificationOptions.map {
                EventNotificationTimeOptionMapper(option: $0)
            }
            let data = try? JSONEncoder().encode(mappers)
            return data.flatMap { String(data: $0, encoding: .utf8) }
        case .repeatingEndCount:
            return entity.repeating?.repeatingEndOption?.endCount
        }
    }
}
