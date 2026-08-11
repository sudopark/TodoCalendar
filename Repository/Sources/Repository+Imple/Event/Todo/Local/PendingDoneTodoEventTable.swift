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
        case repeatingEndCount = "repeating_count"
        case repeatingTurn = "repeating_turn"
        case timeType = "time_type"
        case timeLowerBound = "time_lower_bound"
        case timeUpperBound = "time_upper_bound"
        case secondsFromGMT = "seconds_from_gmt"

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
            case .repeatingEndCount: return .integer([])
            case .repeatingTurn: return .integer([])
            case .timeType: return .text([])
            case .timeLowerBound: return .real([])
            case .timeUpperBound: return .real([])
            case .secondsFromGMT: return .real([])
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
        case 6:
            let columnNames = PendingDoneTodoEventTableV6TempTable.columnNamesExistsInV6
            return Self.modfiyColumns(
                tempTable: PendingDoneTodoEventTableV6TempTable.tableName,
                to: columnNames,
                from: columnNames
            )
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
        case .repeatingEndCount: return entity.todoEvent.repeating?.repeatingEndOption?.endCount
        case .repeatingTurn: return entity.todoEvent.repeatingTurn
        case .timeType: return entity.todoEvent.time?.typeText
        case .timeLowerBound: return entity.todoEvent.time?.lowerBoundWithFixed
        case .timeUpperBound: return entity.todoEvent.time?.upperBoundWithFixed
        case .secondsFromGMT: return entity.todoEvent.time?.secondsFromGMT ?? 0
        }
    }
}

// v7 스키마로 동결 — 살아있는 Columns 를 참조하면 이후 컬럼 추가가 v6 원본에 없는 이름을 복사 목록에 실어 깨진다
struct PendingDoneTodoEventTableV6TempTable: Table {

    enum Columns: String, TableColumn {
        case uuid
        case name
        case createTimeStamp = "create_timestamp"
        case eventTagId = "tag_id"
        case repeatingStart = "repeating_start"
        case repeatingOption = "repeating_option"
        case repeatingEnd = "repeating_end"
        case notificationOptions = "notification_options"
        case repeatingEndCount = "repeating_count"
        case repeatingTurn = "repeating_turn"
        case timeType = "time_type"
        case timeLowerBound = "time_lower_bound"
        case timeUpperBound = "time_upper_bound"
        case secondsFromGMT = "seconds_from_gmt"

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
            case .repeatingEndCount: return .integer([])
            case .repeatingTurn: return .integer([])
            case .timeType: return .text([])
            case .timeLowerBound: return .real([])
            case .timeUpperBound: return .real([])
            case .secondsFromGMT: return .real([])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = PendingDoneTodoEventTable.PendingDoneTodo
    static var tableName: String { "PendingDoneTodoEvent_v6" }

    static var columnNamesExistsInV6: [String] {
        return Columns.allCases
            .filter { $0 != .repeatingTurn }
            .map { $0.rawValue }
    }

    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        guard let liveColumn = PendingDoneTodoEventTable.Columns(rawValue: column.rawValue)
        else { return nil }
        return PendingDoneTodoEventTable.scalar(entity, for: liveColumn)
    }
}
