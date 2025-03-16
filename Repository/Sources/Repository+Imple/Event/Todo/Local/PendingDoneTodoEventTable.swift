//
//  PendingDoneTodoEventTable.swift
//  Repository
//
//  Created by sudo.park on 7/22/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain
import Extensions


struct PendingDoneTodoEventTable: Table {
    
    enum Columns: String, TableColumn {
        case uuid
        case name
        case createTimeStamp = "create_timestamp"
        case eventTagId = "tag_id"
        case repeatingStart = "repeating_start"
        case repeatingOption = "repeating_option"
        case repeatingEnd = "repeating_end"
        case notificationOptions = "notification_options"
        case timeType = "time_type"
        case timeLowerBound = "time_lower_bound"
        case timeUpperBound = "time_upper_bound"
        case secondsFromGMT = "seconds_from_gmt"
        case repeatingEndCount = "repeating_count"
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .createTimeStamp: return .real([])
            case .eventTagId: return .text([])
            case .repeatingStart: return .real([])
            case .repeatingOption: return .text([])
            case .repeatingEnd: return .real([])
            case .notificationOptions: return .text([])
            case .timeType: return .text([])
            case .timeLowerBound: return .real([])
            case .timeUpperBound: return .real([])
            case .secondsFromGMT: return .real([])
            case .repeatingEndCount: return .integer([])
            }
        }
    }
    
    struct PendingDoneTodo: RowValueType {
        var todoEvent: TodoEvent
        
        init(todoEvent: TodoEvent) {
            self.todoEvent = todoEvent
        }
        
        init(_ cursor: CursorIterator) throws {
            todoEvent = try TodoEvent(cursor)
            let timeType: String? = cursor.next()
            let timeLowerInterval: Double? = cursor.next()
            let timeUpperInterval: Double? = cursor.next()
            let secondsFromGMT: Double? = cursor.next()
            
            switch timeType {
            case "at":
                guard let lower = timeLowerInterval else { return }
                self.todoEvent.time = .at(lower)
                
            case "period":
                guard let lower = timeLowerInterval, 
                      let upper = timeUpperInterval 
                else { return }
                self.todoEvent.time = .period(lower..<upper)
            case "allday":
                guard let lower = timeLowerInterval, 
                      let upper = timeUpperInterval,
                      let offset = secondsFromGMT
                else { return }
                self.todoEvent.time = .allDay(lower..<upper, secondsFromGMT: offset)
            default: break
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = PendingDoneTodo
    static var tableName: String { "PendingDoneTodoEvent" }
    
    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 0:
            return Self.addColumnStatement(.repeatingEndCount)
        default: return nil
        }
    }
    
    static func scalar(_ entity: PendingDoneTodo, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .uuid: return  entity.todoEvent.uuid
        case .name: return entity.todoEvent.name
        case .createTimeStamp: return entity.todoEvent.creatTimeStamp
        case .eventTagId: return entity.todoEvent.eventTagId?.customTagId
        case .repeatingStart: return entity.todoEvent.repeating?.repeatingStartTime
        case .repeatingOption: return entity.todoEvent.repeating
                .map { EventRepeatingOptionCodableMapper(option: $0.repeatOption) }
                .flatMap { try? JSONEncoder().encode($0) }
                .flatMap { String(data: $0, encoding: .utf8) }
            
        case .repeatingEnd: return entity.todoEvent.repeating?.repeatingEndOption?.endTime
        case .notificationOptions:
            let mappers = entity.todoEvent.notificationOptions.map { EventNotificationTimeOptionMapper(option: $0) }
            let data = try? JSONEncoder().encode(mappers)
            return data.flatMap { String(data: $0, encoding: .utf8) }
        case .timeType: return entity.todoEvent.time?.typeText
        case .timeLowerBound: return entity.todoEvent.time?.lowerBoundWithFixed
        case .timeUpperBound: return entity.todoEvent.time?.upperBoundWithFixed
        case .secondsFromGMT: return entity.todoEvent.time?.secondsFromGMT ?? 0
        case .repeatingEndCount: return entity.todoEvent.repeating?.repeatingEndOption?.endCount
        }
    }
}
