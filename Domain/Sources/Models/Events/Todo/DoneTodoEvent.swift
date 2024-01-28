//
//  DoneTodoEvent.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


// 생성 메커니즘
// time 정보가 없는 event 완료처리시에 -> 기존 todo event 삭제하고 DoneTodoEvent로 이관
// time 정보가 있지만 반복은 안하는 event 완료 처리시에 -> 기존 todo event 삭제하고 DoneTodoEvent로 이관
// time 정보가 있고 반복하는 이벤트 중 하나가 완료처리된 경우 -> 기존 todo event는 유지하고 완료한 일정을 DoneTodoEvent로 이관

// TodoEvent에 부가정보가 더 추가되는 경우 -> 일단 DoneTodoEvent에 고유 정보 + summary 개념의 정보들로만 만들고
// 상세 정보는 TodoDetail에 있게, 상세 조회시에만 로드할수있도록 아니면 아예 분리해서 저장하던지

public struct DoneTodoEvent {
    
    public let uuid: String
    public let originEventId: String
    public let name: String
    
    public var eventTagId: AllEventTagId?
    public var eventTime: EventTime?
    public let doneTime: Date
    public var notificationOptions: [EventNotificationTimeOption] = []
    
    public init(uuid: String, name: String, originEventId: String, doneTime: Date) {
        self.uuid = uuid
        self.name = name
        self.originEventId = originEventId
        self.doneTime = doneTime
    }
    
    public init(_ origin: TodoEvent) {
        self.uuid = UUID().uuidString
        self.originEventId = origin.uuid
        self.name = origin.name
        self.eventTagId = origin.eventTagId
        self.eventTime = origin.time
        self.doneTime = Date()
        self.notificationOptions = origin.notificationOptions
    }
}

public struct CompleteTodoResult {
    
    public let doneEvent: DoneTodoEvent
    public var nextRepeatingTodoEvent: TodoEvent?
    
    public init(doneEvent: DoneTodoEvent, nextRepeatingTodoEvent: TodoEvent? = nil) {
        self.doneEvent = doneEvent
        self.nextRepeatingTodoEvent = nextRepeatingTodoEvent
    }
}
