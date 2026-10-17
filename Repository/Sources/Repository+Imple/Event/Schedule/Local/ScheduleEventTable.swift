//
//  ScheduleEventTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/27.
//

import Foundation
import Prelude
import Optics
import SQLiteServiceMacros
import Domain
import Extensions


typealias ScheduleEventTable = ScheduleEventTableV1

@Table("Schedules")
struct ScheduleEventTableV1 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let uuid: String
    
    @Column(.notNull)
    let name: String
    
    @Column(name: "tag_id")
    var eventTagId: String?
    
    @Column(name: "repeating_start")
    var repeatingStart: Double?
    
    @Column(name: "repeating_option")
    var repeatingOption: String?
    
    @Column(name: "repeating_end")
    var repeatingEnd: Double?
    
    @Column(.notNull, .default(0), name: "show_turn")
    let showTurn: Bool
    
    @Column(name: "exclude_times")
    var excludeTimes: String?
    
    @Column(name: "notification_options")
    var notificationOptions: String?
    
    @Column(name: "repeating_count")
    var repeatingEndCount: Int?
}


// MARK: - 과거 버전 스키마 선언

@Table("Schedules")
struct ScheduleEventTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let uuid: String
    
    @Column(.notNull)
    let name: String
    
    @Column(name: "tag_id")
    var eventTagId: String?
    
    @Column(name: "repeating_start")
    var repeatingStart: Double?
    
    @Column(name: "repeating_option")
    var repeatingOption: String?
    
    @Column(name: "repeating_end")
    var repeatingEnd: Double?
    
    @Column(.notNull, .default(0), name: "show_turn")
    let showTurn: Bool
    
    @Column(name: "exclude_times")
    var excludeTimes: String?
    
    @Column(name: "notification_options")
    var notificationOptions: String?
}


extension ScheduleEventTable {
    
    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 0:
            return Self.addColumnStatement(.repeatingEndCount)
        default: return nil
        }
    }
}


// MARK: - ScheduleEvent 변환

extension ScheduleEventTable.Entity {
    
    init(_ event: ScheduleEvent) {
        let optionText = event.repeating
            .map { EventRepeatingOptionCodableMapper(option: $0.repeatOption) }
            .flatMap { try? JSONEncoder().encode($0) }
            .flatMap { String(data: $0, encoding: .utf8) }
        let excludeTimesText = (try? JSONEncoder().encode(Array(event.repeatingTimeToExcludes)))
            .flatMap { String(data: $0, encoding: .utf8) }
        let notificationMappers = event.notificationOptions.map {
            EventNotificationTimeOptionMapper(option: $0)
        }
        let notificationText = (try? JSONEncoder().encode(notificationMappers))
            .flatMap { String(data: $0, encoding: .utf8) }
        
        self.init(
            uuid: event.uuid,
            name: event.name,
            eventTagId: event.eventTagId?.stringValue,
            repeatingStart: event.repeating?.repeatingStartTime,
            repeatingOption: optionText,
            repeatingEnd: event.repeating?.repeatingEndOption?.endTime,
            showTurn: event.showTurn,
            excludeTimes: excludeTimesText,
            notificationOptions: notificationText,
            repeatingEndCount: event.repeating?.repeatingEndOption?.endCount
        )
    }
    
    func asScheduleEvent(with time: EventTime) throws -> ScheduleEvent {
        let event = ScheduleEvent(uuid: self.uuid, name: self.name, time: time)
            |> \.eventTagId .~ self.eventTagId.flatMap { EventTagId($0) }
            |> \.showTurn .~ self.showTurn
            |> \.repeatingTimeToExcludes .~ Set(self.decodedExcludeTimes())
            |> \.notificationOptions .~ self.decodedNotificationOptions()
        
        guard let repeating = try self.decodedRepeating() else { return event }
        return event |> \.repeating .~ pure(repeating)
    }
    
    private func decodedExcludeTimes() -> [String] {
        return self.excludeTimes?.data(using: .utf8)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) }
            ?? []
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
