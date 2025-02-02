//
//  ForemostEvent.swift
//  Domain
//
//  Created by sudo.park on 6/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - ForemostMarkableEvent

public protocol ForemostMarkableEvent: Sendable {
    var eventId: String { get }
    var eventTagId: EventTagId? { get }
}

extension TodoEvent: ForemostMarkableEvent {
    public var eventId: String { self.uuid }
}

extension ScheduleEvent: ForemostMarkableEvent {
    public var eventId: String { self.uuid }
}


// MARK: - ForemostEventId

public struct ForemostEventId: Sendable, Equatable {
    
    public let eventId: String
    public let isTodo: Bool
    
    public init(_ eventId: String, _ isTodo: Bool) {
        self.eventId = eventId
        self.isTodo = isTodo
    }
    
    public init(event: any ForemostMarkableEvent) {
        self.eventId = event.eventId
        self.isTodo = event is TodoEvent
    }
}
