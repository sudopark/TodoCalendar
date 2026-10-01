//
//  PendingDoneTodoEventTable.swift
//  Repository
//
//  Created by sudo.park on 7/22/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import SQLiteService
import SQLiteServiceMacros
import Domain


typealias PendingDoneTodoEventTable = PendingDoneTodoEventTableV7

@Table("PendingDoneTodoEvent")
struct PendingDoneTodoEventTableV7 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let uuid: String
    
    @Column(.notNull)
    let name: String
    
    @Column(name: "create_timestamp")
    var createTimeStamp: Double?
    
    @Column(name: "tag_id")
    var eventTagId: String?
    
    @Column(name: "repeating_start")
    var repeatingStart: Double?
    
    @Column(name: "repeating_option")
    var repeatingOption: String?
    
    @Column(name: "repeating_end")
    var repeatingEnd: Double?
    
    @Column(name: "notification_options")
    var notificationOptions: String?
    
    @Column(name: "repeating_count")
    var repeatingEndCount: Int?
    
    @Column(name: "repeating_turn")
    var repeatingTurn: Int?
    
    @Column(name: "time_type")
    var timeType: String?
    
    @Column(name: "time_lower_bound")
    var timeLowerBound: Double?
    
    @Column(name: "time_upper_bound")
    var timeUpperBound: Double?
    
    @Column(name: "seconds_from_gmt")
    var secondsFromGMT: Double?
}


// MARK: - 과거 버전 스키마 선언

// 0→1 과 6→7 이 두 컬럼을 붙이기 전 스키마다
@Table("PendingDoneTodoEvent")
struct PendingDoneTodoEventTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let uuid: String
    
    @Column(.notNull)
    let name: String
    
    @Column(name: "create_timestamp")
    var createTimeStamp: Double?
    
    @Column(name: "tag_id")
    var eventTagId: String?
    
    @Column(name: "repeating_start")
    var repeatingStart: Double?
    
    @Column(name: "repeating_option")
    var repeatingOption: String?
    
    @Column(name: "repeating_end")
    var repeatingEnd: Double?
    
    @Column(name: "notification_options")
    var notificationOptions: String?
    
    @Column(name: "time_type")
    var timeType: String?
    
    @Column(name: "time_lower_bound")
    var timeLowerBound: Double?
    
    @Column(name: "time_upper_bound")
    var timeUpperBound: Double?
    
    @Column(name: "seconds_from_gmt")
    var secondsFromGMT: Double?
}

// 0→1 이 붙인 repeating_count 가 ALTER 탓에 맨 뒤에 온 상태다 — 6→7 이 선언 순서로 바로잡는다
@Table("PendingDoneTodoEvent")
struct PendingDoneTodoEventTableV1 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let uuid: String
    
    @Column(.notNull)
    let name: String
    
    @Column(name: "create_timestamp")
    var createTimeStamp: Double?
    
    @Column(name: "tag_id")
    var eventTagId: String?
    
    @Column(name: "repeating_start")
    var repeatingStart: Double?
    
    @Column(name: "repeating_option")
    var repeatingOption: String?
    
    @Column(name: "repeating_end")
    var repeatingEnd: Double?
    
    @Column(name: "notification_options")
    var notificationOptions: String?
    
    @Column(name: "time_type")
    var timeType: String?
    
    @Column(name: "time_lower_bound")
    var timeLowerBound: Double?
    
    @Column(name: "time_upper_bound")
    var timeUpperBound: Double?
    
    @Column(name: "seconds_from_gmt")
    var secondsFromGMT: Double?
    
    @Column(name: "repeating_count")
    var repeatingEndCount: Int?
}


extension PendingDoneTodoEventTable {
    
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
}


// MARK: - TodoEvent 변환

extension PendingDoneTodoEventTable.Entity {
    
    init(_ todo: TodoEvent) {
        let base = TodoEventTable.Entity(todo)
        self.init(
            uuid: base.uuid,
            name: base.name,
            createTimeStamp: base.createTimeStamp,
            eventTagId: base.eventTagId,
            repeatingStart: base.repeatingStart,
            repeatingOption: base.repeatingOption,
            repeatingEnd: base.repeatingEnd,
            notificationOptions: base.notificationOptions,
            repeatingEndCount: base.repeatingEndCount,
            repeatingTurn: base.repeatingTurn,
            timeType: todo.time?.typeText,
            timeLowerBound: todo.time?.lowerBoundWithFixed,
            timeUpperBound: todo.time?.upperBoundWithFixed,
            secondsFromGMT: todo.time?.secondsFromGMT ?? 0
        )
    }
    
    func asTodoEvent() throws -> TodoEvent {
        let todo = try TodoEventTable.Entity(
            uuid: self.uuid,
            name: self.name,
            createTimeStamp: self.createTimeStamp,
            eventTagId: self.eventTagId,
            repeatingStart: self.repeatingStart,
            repeatingOption: self.repeatingOption,
            repeatingEnd: self.repeatingEnd,
            notificationOptions: self.notificationOptions,
            repeatingEndCount: self.repeatingEndCount,
            repeatingTurn: self.repeatingTurn
        ).asTodoEvent()
        
        guard let time = self.decodedTime() else { return todo }
        return todo |> \.time .~ pure(time)
    }
    
    private func decodedTime() -> EventTime? {
        switch self.timeType {
        case "at":
            guard let lower = self.timeLowerBound else { return nil }
            return .at(lower)
        case "period":
            guard let lower = self.timeLowerBound,
                  let upper = self.timeUpperBound
            else { return nil }
            return .period(lower..<upper)
        case "allday":
            guard let lower = self.timeLowerBound,
                  let upper = self.timeUpperBound,
                  let offset = self.secondsFromGMT
            else { return nil }
            return .allDay(lower..<upper, secondsFromGMT: offset)
        default: return nil
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
    typealias EntityType = PendingDoneTodoEventTableV7.Entity
    static var tableName: String { "PendingDoneTodoEvent_v6" }

    static var columnNamesExistsInV6: [String] {
        return Columns.allCases
            .filter { $0 != .repeatingTurn }
            .map { $0.rawValue }
    }

    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        guard let liveColumn = PendingDoneTodoEventTableV7.Columns(rawValue: column.rawValue)
        else { return nil }
        return PendingDoneTodoEventTableV7.scalar(entity, for: liveColumn)
    }
}
