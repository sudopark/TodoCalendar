//
//  EventTimeTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
import Domain
import SQLiteService


struct EventTimeTable: Table {
    
    enum Columns: String, TableColumn {
        case eventId = "event_id"
        case timeType = "time_type"
        case timezone
        case lowerInterval = "l_interval"
        case upperInterval = "u_interval"
        
        var dataType: ColumnDataType {
            switch self {
            case .eventId: return .text([.unique, .notNull])
            case .timeType: return .text([.notNull])
            case .timezone: return .text([.notNull])
            case .lowerInterval: return .real([.notNull])
            case .upperInterval: return .real([.notNull])
            }
        }
    }
    
    struct Entity: RowValueType {
        let eventTime: EventTime
        let eventId: String
        
        init(_ cursor: CursorIterator) throws {
            self.eventId = try cursor.next().unwrap()
            let timeType: String = try cursor.next().unwrap()
            let timeZone: String = try cursor.next().unwrap()
            let lowerInterval: Double = try cursor.next().unwrap()
            let upperInterval: Double = try cursor.next().unwrap()
            if timeType == "at" {
                let interval: Double = try cursor.next().unwrap()
                self.eventTime = .at(TimeStamp(interval, timeZone: timeZone))
            } else {
                self.eventTime = .period(TimeStamp(lowerInterval, timeZone: timeZone)..<TimeStamp(upperInterval, timeZone: timeZone))
            }
        }
    }
    
    static var tableName: String { "EventTimes" }
    typealias ColumnType = Columns
    typealias EntityType = Entity
    
    static func scalar(_ entity: Entity, for column: Columns) -> ScalarType? {
        switch column {
        case .eventId: return entity.eventId
        case .timeType: return entity.eventTime.typeText
        case .timezone: return entity.eventTime.lowerBoundTimeStamp.timeZoneAbbreviation
        case .lowerInterval: return entity.eventTime.lowerBoundTimeStamp.utcTimeInterval
        case .upperInterval: return entity.eventTime.upperBoundWitShifttingIfNeed
        }
    }
}

private extension EventTime {
    var typeText: String {
        switch self {
        case .at: return "at"
        case .period: return "period"
        }
    }
    
    var upperBoundWitShifttingIfNeed: TimeInterval {
        switch self {
        case .at(let time): return time.utcTimeInterval + 1
        case .period(let range): return range.upperBound.utcTimeInterval
        }
    }
}
