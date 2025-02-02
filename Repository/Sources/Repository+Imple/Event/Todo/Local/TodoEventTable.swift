//
//  TodoTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
import SQLiteService
import Domain
import Extensions


struct TodoEventTable: Table {
    
    enum Columns: String, TableColumn {
        case uuid
        case name
        case createTimeStamp = "create_timestamp"
        case eventTagId = "tag_id"
        case repeatingStart = "repeating_start"
        case repeatingOption = "repeating_option"
        case repeatingEnd = "repeating_end"
        case notificationOptions = "notification_options"
        
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
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = TodoEvent
    static var tableName: String { "TodoEvents" }
    
    static func scalar(_ entity: TodoEvent, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .uuid: return  entity.uuid
        case .name: return entity.name
        case .createTimeStamp: return entity.creatTimeStamp
        case .eventTagId: return entity.eventTagId?.customTagId
        case .repeatingStart: return entity.repeating?.repeatingStartTime
        case .repeatingOption: return entity.repeating
                .map { EventRepeatingOptionCodableMapper(option: $0.repeatOption) }
                .flatMap { try? JSONEncoder().encode($0) }
                .flatMap { String(data: $0, encoding: .utf8) }
            
        case .repeatingEnd: return entity.repeating?.repeatingEndTime
        case .notificationOptions:
            let mappers = entity.notificationOptions.map { EventNotificationTimeOptionMapper(option: $0) }
            let data = try? JSONEncoder().encode(mappers)
            return data.flatMap { String(data: $0, encoding: .utf8) }
        }
    }
    
}

extension TodoEvent: RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            uuid: try cursor.next().unwrap(),
            name: try cursor.next().unwrap()
        )
        self.creatTimeStamp = cursor.next()
        self.eventTagId = cursor.next().map { EventTagId($0) }
        let start: Double? = cursor.next()
        let optionText: String? = cursor.next()
        let end: Double? = cursor.next()
        let notificationOptionText: String? = cursor.next()
        
        let notificationOpionMappers = notificationOptionText?.data(using: .utf8)
            .flatMap {
                try? JSONDecoder().decode([EventNotificationTimeOptionMapper].self, from: $0)
            }
        self.notificationOptions = notificationOpionMappers?.map { $0.option } ?? []
        
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
        self.repeating?.repeatingEndTime = end
    }
}


