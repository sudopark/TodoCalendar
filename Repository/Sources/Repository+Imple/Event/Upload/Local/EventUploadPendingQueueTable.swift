//
//  EventUploadPendingQueueTable.swift
//  Repository
//
//  Created by sudo.park on 7/21/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import SQLiteService
import SQLiteServiceMacros
import Domain
import Extensions


typealias EventUploadPendingQueueTable = EventUploadPendingQueueTableV5

@Table("event_upload_pending_queue")
struct EventUploadPendingQueueTableV5 {
    
    @Column(.notNull)
    let timestamp: Double
    
    @Column(.notNull, name: "data_type")
    let dataType: String
    
    @Column(.notNull)
    let uuid: String
    
    @Column(.default(0), .notNull, name: "is_remove")
    let isRemove: Bool
    
    @Column(.default(0), .notNull, name: "upload_fail_count")
    let uploadFailCount: Int
}


extension EventUploadPendingQueueTable {
    
    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 4:
            return Self.modfiyColumns(
                tempTable: EventUploadPendingQueueTableV4TempTable.tableName,
                to: Columns.allCases.map { $0.rawValue },
                from: Columns.allCases.map { $0.rawValue }
            )
        default: return nil
        }
    }
}


// MARK: - EventUploadingTask 변환

extension EventUploadPendingQueueTable.Entity {
    
    init(_ task: EventUploadingTask) {
        self.init(
            timestamp: task.timestamp,
            dataType: task.dataType.rawValue,
            uuid: task.uuid,
            isRemove: task.isRemovingTask,
            uploadFailCount: task.uploadFailCount
        )
    }
    
    func asUploadingTask() throws -> EventUploadingTask {
        return EventUploadingTask(
            timestamp: self.timestamp,
            dataType: try EventUploadingTask.DataType(rawValue: self.dataType).unwrap(),
            uuid: self.uuid,
            isRemovingTask: self.isRemove
        )
        |> \.uploadFailCount .~ self.uploadFailCount
    }
}


struct EventUploadPendingQueueTableV4TempTable: Table {
    
    enum Colunms: String, TableColumn {
        case timestamp
        case dataType = "data_type"
        case uuid
        case isRemove = "is_remove"
        case uploadFailCount = "upload_fail_count"
        
        var dataType: ColumnDataType {
            switch self {
            case .timestamp: return .real([.notNull])
            case .dataType: return .text([.notNull])
            case .uuid: return .text([.notNull])
            case .isRemove: return .integer([.default(0), .notNull])
            case .uploadFailCount: return .integer([.default(0), .notNull])
            }
        }
    }
    
    typealias ColumnType = Colunms
    typealias EntityType = EventUploadPendingQueueTableV5.Entity
    static var tableName: String { "event_upload_pending_queue_v4" }
    
    static func scalar(_ entity: EntityType, for column: Colunms) -> (any ScalarType)? {
        guard let liveColumn = EventUploadPendingQueueTableV5.Columns(rawValue: column.rawValue)
        else { return nil }
        return EventUploadPendingQueueTableV5.scalar(entity, for: liveColumn)
    }
}


// 4→5 가 uuid 의 unique 를 떼기 전 스키마다 — ALTER 로 제약을 못 떼 temp 로 복사·교체한다(#545)
@Table("event_upload_pending_queue")
struct EventUploadPendingQueueTableV4 {
    
    @Column(.notNull)
    let timestamp: Double
    
    @Column(.notNull, name: "data_type")
    let dataType: String
    
    @Column(.unique, .notNull)
    let uuid: String
    
    @Column(.default(0), .notNull, name: "is_remove")
    let isRemove: Bool
    
    @Column(.default(0), .notNull, name: "upload_fail_count")
    let uploadFailCount: Int
}


// MARK: - EventUploadingTask 변환 (V4)

extension EventUploadPendingQueueTableV4.Entity {
    
    init(_ task: EventUploadingTask) {
        self.init(
            timestamp: task.timestamp,
            dataType: task.dataType.rawValue,
            uuid: task.uuid,
            isRemove: task.isRemovingTask,
            uploadFailCount: task.uploadFailCount
        )
    }
}
