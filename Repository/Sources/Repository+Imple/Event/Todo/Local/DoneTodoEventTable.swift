//
//  DoneTodoEventTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/21.
//

import Foundation
import Prelude
import Optics
import SQLiteServiceMacros
import Domain


typealias DoneTodoEventTable = DoneTodoEventTableV0

@Table("DoneTodos")
struct DoneTodoEventTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .notNull)
    let uuid: String
    
    @Column(.notNull, name: "origin_event_id")
    let originEventId: String
    
    @Column(.notNull)
    let name: String
    
    @Column(.notNull, name: "done_time")
    let doneTime: Double
    
    @Column(name: "tag_id")
    var eventTagId: String?
    
    @Column(name: "notification_options")
    var notificationOptions: String?
}


// MARK: - DoneTodoEvent 변환

extension DoneTodoEventTable.Entity {
    
    init(_ done: DoneTodoEvent) {
        let notificationMappers = done.notificationOptions.map {
            EventNotificationTimeOptionMapper(option: $0)
        }
        let notificationText = (try? JSONEncoder().encode(notificationMappers))
            .flatMap { String(data: $0, encoding: .utf8) }
        
        self.init(
            uuid: done.uuid,
            originEventId: done.originEventId,
            name: done.name,
            doneTime: done.doneTime.timeIntervalSince1970,
            eventTagId: done.eventTagId?.stringValue,
            notificationOptions: notificationText
        )
    }
    
    func asDoneTodoEvent() throws -> DoneTodoEvent {
        return DoneTodoEvent(
            uuid: self.uuid,
            name: self.name,
            originEventId: self.originEventId,
            doneTime: Date(timeIntervalSince1970: self.doneTime)
        )
        |> \.eventTagId .~ self.eventTagId.flatMap { EventTagId($0) }
        |> \.notificationOptions .~ self.decodedNotificationOptions()
    }
    
    private func decodedNotificationOptions() -> [EventNotificationTimeOption] {
        let mappers = self.notificationOptions?.data(using: .utf8)
            .flatMap {
                try? JSONDecoder().decode([EventNotificationTimeOptionMapper].self, from: $0)
            }
        return mappers?.map { $0.option } ?? []
    }
}
