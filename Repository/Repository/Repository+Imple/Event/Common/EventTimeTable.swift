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
    
    static func overlapQuery(with range: Range<TimeInterval>) -> SelectQuery<EventTimeTable> {
        // 항상 l <= u, L <= U 이고
        // todo의 기간이 l..<u 이며 조회 기간이 L..<U 이라 할때
        // 조회에서 제외되는 조건은 ( l < L && u < L) || ( U <= l && U <= u)
        // 이를 뒤집으면 => (l >= L || u >= L) && ( U > l ||  U > u)
        
        // 1. endtime이 없는경우 null로 저장되기떄문에 l,u >= L 인지 판단하는 로직을 대신해여함
        // 2. l, u < U의 경우는 u가 무한이라면 성립하지 않기 때문에 검사 불필요
        // 1번의 경우 currentTime인 경우도 같이 조회될수있기때문에 filtering 해줘야함 -> upper bound가 null 인 경우는 current Todo 이거나 반복일정이 없는경우만 해당되기 때문에
        // current는 조회에서 제외될것이고 -> lowerInterval 없어서 필터잉
        // 반복일정이 없는 경우는 lower=upper 이기때문에 조건식을 만족못하면 걸러짐
        let timeQuery = Self.selectAll()
            .where {
                $0.lowerInterval >= range.lowerBound
                ||
                $0.upperInterval >= range.lowerBound
                ||
                $0.upperInterval.isNull()
            }
            .where {
                $0.lowerInterval < range.upperBound
                ||
                $0.upperInterval < range.upperBound
            }
        return timeQuery
    }
    
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
    
    static func scalar(_ entity: Entity, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .eventId: return entity.eventId
        case .timeType: return entity.eventTime?.typeText
        case .timeLowerInterval:
            return entity.eventTime?.lowerBoundWithFixed
        case .timeUpperInterval:
            return entity.eventTime?.upperBoundWithFixed
        case .lowerInterval:
            guard let time = entity.eventTime
            else { return nil }
            return entity.repeating?.startTime(for: time) ?? time.lowerBoundWithExtended

        case .upperInterval:
            guard let time = entity.eventTime
            else { return nil }
            
            if let repeating = entity.repeating {
                return repeating.endTime(for: time)
            } else {
                return time.upperBoundWithExtended
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
    
    var lowerBoundWithExtended: TimeInterval {
        switch self {
        case .allDay(let range, let secondsFromGMT):
            return range.lowerBound.earlistTimeZoneInterval(secondsFromGMT)
        default: return self.lowerBoundWithFixed
        }
    }
    
    var upperBoundWithExtended: TimeInterval {
        switch self {
        case .allDay(let range, let secondsFromGMT):
            return range.upperBound.latestTimeZoneInterval(secondsFromGMT)
        default: return self.upperBoundWithFixed
        }
    }
}
