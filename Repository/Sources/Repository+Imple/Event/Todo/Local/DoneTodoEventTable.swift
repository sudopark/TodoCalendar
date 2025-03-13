//
//  DoneTodoEventTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/21.
//

import Foundation
import SQLiteService
import Domain
import Extensions


struct DoneTodoEventTable: Table {
    
    enum Colums: String, TableColumn {
        case uuid
        case originEventId = "origin_event_id"
        case name
        case doneTime = "done_time"
        case eventTagId = "tag_id"
        case notificationOptions = "notification_options"
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .notNull])
            case .originEventId: return .text([.notNull])
            case .name: return .text([.notNull])
            case .doneTime: return .real([.notNull])
            case .eventTagId: return .text([])
            case .notificationOptions: return .text([])
            }
        }
    }
    
    typealias ColumnType = Colums
    typealias EntityType = DoneTodoEvent
    static var tableName: String { "DoneTodos" }
    
    static func scalar(_ entity: EntityType, for column: Colums) -> (any ScalarType)? {
        switch column {
        case .uuid: return entity.uuid
        case .originEventId: return entity.originEventId
        case .name: return entity.name
        case .doneTime: return entity.doneTime.timeIntervalSince1970
        case .eventTagId: return entity.eventTagId?.stringValue
        case .notificationOptions:
            let mappers = entity.notificationOptions.map {
                EventNotificationTimeOptionMapper(option: $0)
            }
            let data = try? JSONEncoder().encode(mappers)
            return data.flatMap { String(data: $0, encoding: .utf8) }
        }
    }
}

extension DoneTodoEvent: RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        let uuid: String = try cursor.next().unwrap()
        let origin: String = try cursor.next().unwrap()
        let name: String = try cursor.next().unwrap()
        self.init(
            uuid: uuid,
            name: name,
            originEventId: origin,
            doneTime: Date(timeIntervalSince1970: try cursor.next().unwrap())
        )
        self.eventTagId = cursor.next().flatMap { EventTagId($0) }
        let notificationOptionText: String? = cursor.next()
        let mappers = notificationOptionText?.data(using: .utf8)
            .flatMap {
                try? JSONDecoder().decode([EventNotificationTimeOptionMapper].self, from: $0)
            }
        self.notificationOptions = mappers?.map { $0.option } ?? []
    }
}
