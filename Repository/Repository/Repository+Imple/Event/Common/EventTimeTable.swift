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
        case timeLowerInterval = "tl_interval"
        case timeUpperInterval = "tu_interval"
        case lowerInterval = "l_interval"
        case upperInterval = "u_interval"
        
        var dataType: ColumnDataType {
            switch self {
            case .eventId: return .text([.unique, .notNull])
            case .timeType: return .text([])
            case .timezone: return .text([])
            case .timeLowerInterval: return .real([])
            case .timeUpperInterval: return .real([])
            case .lowerInterval: return .real([])
            case .upperInterval: return .real([])
            }
        }
    }
    
    struct Entity: RowValueType {
        let eventTime: EventTime?
        let eventId: String
        fileprivate var repeating: EventRepeating?
        
        init(_ cursor: CursorIterator) throws {
            self.eventId = try cursor.next().unwrap()
            guard let timeType: String = try? cursor.next().unwrap(),
                  let timeZone: String = try? cursor.next().unwrap(),
                  let timeLowerInterval: Double = try? cursor.next().unwrap(),
                  let timeUpperInterval: Double = try? cursor.next().unwrap()
            else{
                self.eventTime = nil
                return
            }
            let _: Double? = cursor.next()
            let _: Double? = cursor.next()
            
            if timeType == "at" {
                self.eventTime = .at(TimeStamp(timeLowerInterval, timeZone: timeZone))
            } else {
                self.eventTime = .period(TimeStamp(timeLowerInterval, timeZone: timeZone)..<TimeStamp(timeUpperInterval, timeZone: timeZone))
            }
        }
        
        init(_ eventId: String, _ time: EventTime?, _ repeating: EventRepeating?) {
            self.eventId = eventId
            self.eventTime = time
            self.repeating = repeating
        }
    }
    
    static var tableName: String { "EventTimes" }
    typealias ColumnType = Columns
    typealias EntityType = Entity
    
    static func scalar(_ entity: Entity, for column: Columns) -> ScalarType? {
        switch column {
        case .eventId: return entity.eventId
        case .timeType: return entity.eventTime?.typeText
        case .timezone: return entity.eventTime?.lowerBoundTimeStamp.timeZoneAbbreviation
        case .timeLowerInterval:
            return entity.eventTime?.lowerBoundTimeStamp.utcTimeInterval
        case .timeUpperInterval:
            return entity.eventTime?.upperBoundTimeStamp.utcTimeInterval
        case .lowerInterval:
            return entity.repeating?.repeatingStartTime.utcTimeInterval
                ?? entity.eventTime?.lowerBoundTimeStamp.utcTimeInterval
        case .upperInterval:
            if let repeating = entity.repeating {
                return repeating.repeatingEndTime?.utcTimeInterval
            } else {
                return entity.eventTime?.upperBoundTimeStamp.utcTimeInterval
            }
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
}
