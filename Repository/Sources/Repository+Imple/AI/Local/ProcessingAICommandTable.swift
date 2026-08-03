//
//  ProcessingAICommandTable.swift
//  Repository
//
//  Created by sudo.park on 6/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService
import Domain


struct ProcessingAICommandTable: Table {

    enum Columns: String, TableColumn {
        case jobId = "job_id"
        case isConfirmJob = "is_confirm_job"

        var dataType: ColumnDataType {
            switch self {
            case .jobId: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .isConfirmJob: return .integer([.notNull])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = ProcessingAICommand
    static var tableName: String { "ProcessingAICommand" }

    static func scalar(_ entity: ProcessingAICommand, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .jobId: return entity.jobId
        case .isConfirmJob: return entity.isConfirmJob
        }
    }
}


extension ProcessingAICommand: @retroactive RowValueType {

    public init(_ cursor: CursorIterator) throws {
        self.init(
            jobId: try cursor.next().unwrap(),
            isConfirmJob: try cursor.next().unwrap()
        )
    }
}
