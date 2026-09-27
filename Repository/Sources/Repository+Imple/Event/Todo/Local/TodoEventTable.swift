//
//  TodoTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
import Prelude
import Optics
import SQLiteServiceMacros
import Domain
import Extensions


typealias TodoEventTable = TodoEventTableV6

@Table("TodoEvents")
struct TodoEventTableV6 {
    
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
}


// MARK: - 과거 버전 스키마 선언

@Table("TodoEvents")
struct TodoEventTableV0 {
    
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
}

@Table("TodoEvents")
struct TodoEventTableV1 {
    
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
}


extension TodoEventTable {
    
    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 0:
            return Self.addColumnStatement(.repeatingEndCount)
        case 5:
            return Self.addColumnStatement(.repeatingTurn)
        default: return nil
        }
    }
}


// MARK: - TodoEvent 변환

extension TodoEventTable.Entity {
    
    init(_ todo: TodoEvent) {
        let optionText = todo.repeating
            .map { EventRepeatingOptionCodableMapper(option: $0.repeatOption) }
            .flatMap { try? JSONEncoder().encode($0) }
            .flatMap { String(data: $0, encoding: .utf8) }
        let notificationMappers = todo.notificationOptions.map {
            EventNotificationTimeOptionMapper(option: $0)
        }
        let notificationText = (try? JSONEncoder().encode(notificationMappers))
            .flatMap { String(data: $0, encoding: .utf8) }
        
        self.init(
            uuid: todo.uuid,
            name: todo.name,
            createTimeStamp: todo.creatTimeStamp,
            eventTagId: todo.eventTagId?.customTagId,
            repeatingStart: todo.repeating?.repeatingStartTime,
            repeatingOption: optionText,
            repeatingEnd: todo.repeating?.repeatingEndOption?.endTime,
            notificationOptions: notificationText,
            repeatingEndCount: todo.repeating?.repeatingEndOption?.endCount,
            repeatingTurn: todo.repeatingTurn
        )
    }
    
    func asTodoEvent() throws -> TodoEvent {
        let todo = TodoEvent(uuid: self.uuid, name: self.name)
            |> \.creatTimeStamp .~ self.createTimeStamp
            |> \.eventTagId .~ self.eventTagId.flatMap { EventTagId($0) }
            |> \.notificationOptions .~ self.decodedNotificationOptions()
        
        guard let repeating = try self.decodedRepeating() else { return todo }
        return todo
            |> \.repeating .~ pure(repeating)
            |> \.repeatingTurn .~ self.repeatingTurn
    }
    
    private func decodedNotificationOptions() -> [EventNotificationTimeOption] {
        let mappers = self.notificationOptions?.data(using: .utf8)
            .flatMap {
                try? JSONDecoder().decode([EventNotificationTimeOptionMapper].self, from: $0)
            }
        return mappers?.map { $0.option } ?? []
    }
    
    private func decodedRepeating() throws -> EventRepeating? {
        let optionMapper = self.repeatingOption?.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode(EventRepeatingOptionCodableMapper.self, from: $0) }
        guard let option = optionMapper?.option else { return nil }
        
        guard let startInterval = self.repeatingStart
        else {
            throw RuntimeError("invalid event repeating option")
        }
        let repeating = EventRepeating(
            repeatingStartTime: startInterval,
            repeatOption: option
        )
        if let end = self.repeatingEnd {
            return repeating |> \.repeatingEndOption .~ .until(end)
        }
        if let endCount = self.repeatingEndCount {
            return repeating |> \.repeatingEndOption .~ .count(endCount)
        }
        return repeating
    }
}
