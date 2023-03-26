//
//  TodoEventsDuringThePeriod.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


// 완료된 이벤트 제외
// 특정 기간동안 표시할 todo event를 조회시에
// 1. event time이 없는 완료되지 않은 event 조회 -> TodoEvent 중 eventTime 없는거 => 기본 이거는 처음에만 조회해주면됨 + 과거에는 필요 없는 정보
// 2. event time이 있는 event 조회(반복하는 경우 기간이 포함되는 경우도 포함)
// 3. 같은 기간동안 완료된 이벤트 조회
// 4. 2번 단계에서 조회했던 이벤트 중 완료된 반복이벤트는 제외


// MARK: - RepeatingTodoEventSequence

public struct RepeatingTodoEventSequence {
    
    public let event: TodoEvent
    public var eventTimes: [EventTime] = []
    
    public init(event: TodoEvent) {
        self.event = event
    }
    
    public var eventId: String {
        return self.event.uuid
    }
}


// MARK: Todo events during the period

public struct TodoEventsDuringThePeriod {
    
    public let period: Range<Date>
    public var singleEvents: [TodoEvent] = []
    public var repeatingEvents: [RepeatingTodoEventSequence] = []
    
    public init(_ period: Range<Date>) {
        self.period = period
    }
}
