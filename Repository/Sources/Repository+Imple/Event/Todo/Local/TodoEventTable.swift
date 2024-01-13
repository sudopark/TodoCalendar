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
        case eventTagId = "tag_id"
        case repeatingStart = "repeating_start"
        case repeatingOption = "repeating_option"
        case repeatingEnd = "repeating_end"
        case notificationOption = "notification_option"
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .eventTagId: return .text([])
            case .repeatingStart: return .real([])
            case .repeatingOption: return .text([])
            case .repeatingEnd: return .real([])
            case .notificationOption: return .text([])
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = TodoEvent
    static var tableName: String { "Todos" }
    
    static func scalar(_ entity: TodoEvent, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .uuid: return  entity.uuid
        case .name: return entity.name
        case .eventTagId: return entity.eventTagId?.customTagId
        case .repeatingStart: return entity.repeating?.repeatingStartTime
        case .repeatingOption: return entity.repeating
                .map { EventRepeatingOptionCodableMapper(option: $0.repeatOption) }
                .flatMap { try? JSONEncoder().encode($0) }
                .flatMap { String(data: $0, encoding: .utf8) }
            
        case .repeatingEnd: return entity.repeating?.repeatingEndTime
        case .notificationOption: return entity.notificationOption?.asString
        }
    }
    
}

extension TodoEvent: RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            uuid: try cursor.next().unwrap(),
            name: try cursor.next().unwrap()
        )
        self.eventTagId = cursor.next().map { AllEventTagId($0) }
        let start: Double? = cursor.next()
        let optionText: String? = cursor.next()
        let end: Double? = cursor.next()
        self.notificationOption = cursor.next().flatMap { EventNotificationTimeOption(from: $0) }
        
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


