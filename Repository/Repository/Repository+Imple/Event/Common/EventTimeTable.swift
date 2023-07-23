//
//  EventTimeTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/14.
//

import Foundation
import Domain
import SQLiteService
import Extensions


struct EventTimeTable: Table {
    
    enum Columns: String, TableColumn {
        case eventId = "event_id"
        case timeType = "time_type"
        case timeLowerInterval = "tl_interval"
        case timeUpperInterval = "tu_interval"
        case lowerInterval = "l_interval"
        case upperInterval = "u_interval"
        case secondsFromGMT = "seconds_from_gmt"
        
        var dataType: ColumnDataType {
            switch self {
            case .eventId: return .text([.unique, .notNull])
            case .timeType: return .text([])
            case .timeLowerInterval: return .real([])
            case .timeUpperInterval: return .real([])
            case .lowerInterval: return .real([])
            case .upperInterval: return .real([])
            case .secondsFromGMT: return .real([.default(0.0)])
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
                  let timeLowerInterval: Double = try? cursor.next().unwrap(),
                  let timeUpperInterval: Double = try? cursor.next().unwrap()
            else{
                self.eventTime = nil
                return
            }
            let _: Double? = cursor.next()
            let _: Double? = cursor.next()
            
            let secondsFromGMT: Double = try cursor.next().unwrap()
            
            switch timeType {
            case "at": self.eventTime = .at(timeLowerInterval)
            case "period": self.eventTime = .period(timeLowerInterval..<timeUpperInterval)
            case "allday": self.eventTime = .allDay(timeLowerInterval..<timeUpperInterval, secondsFromGMT: secondsFromGMT)
            default: throw RuntimeError("not defined event time type: \(timeType)")
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
        case .timeLowerInterval:
            return entity.eventTime?.lowerBoundWithFixed
        case .timeUpperInterval:
            return entity.eventTime?.upperBoundWithFixed
        case .lowerInterval:
            // TODO: 저장시 seconds from gmt 고려도 해줘야함
            return entity.repeating?.repeatingStartTime
                ?? entity.eventTime?.lowerBoundWithFixed
        case .upperInterval:
            // TODO: 저장시 seconds from gmt 고려도 해줘야함
            if let repeating = entity.repeating {
                return repeating.repeatingEndTime
            } else {
                return entity.eventTime?.upperBoundWithFixed
            }
        case .secondsFromGMT:
            return entity.eventTime?.secondsFromGMT ?? 0
        }
    }
}

private extension EventTime {
    var typeText: String {
        switch self {
        case .at: return "at"
        case .period: return "period"
        case .allDay: return "allday"
        }
    }
    
    var secondsFromGMT: TimeInterval? {
        guard case let .allDay(_, secondsFromGMT) = self else { return nil }
        return secondsFromGMT
    }
}
