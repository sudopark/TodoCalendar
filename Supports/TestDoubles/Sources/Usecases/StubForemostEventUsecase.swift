//
//  StubForemostEventUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 6/21/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions


open class StubForemostEventUsecase: ForemostEventUsecase, @unchecked Sendable {
    
    private let initialForemostID: ForemostEventId?
    private let foremostEventSubject = CurrentValueSubject<(any ForemostMarkableEvent)?, Never>(nil)
    public init(foremostId: ForemostEventId? = nil) {
        self.initialForemostID = foremostId
    }
    
    open func refresh() {
        let event = self.initialForemostID.map { self.makeDummyEvent($0) }
        self.foremostEventSubject.send(event)
    }
    
    open func update(foremost eventId: ForemostEventId) async throws {
        let event = self.makeDummyEvent(eventId)
        self.foremostEventSubject.send(event)
    }
    
    open func remove() async throws {
        self.foremostEventSubject.send(nil)
    }
    
    open var foremostEvent: AnyPublisher<(any ForemostMarkableEvent)?, Never> {
        return self.foremostEventSubject
            .eraseToAnyPublisher()
    }
    
    private func makeDummyEvent(_ foremostId: ForemostEventId) -> any ForemostMarkableEvent {
        if foremostId.isTodo {
            return TodoEvent(uuid: foremostId.eventId, name: "todo")
        } else {
            return ScheduleEvent(uuid: foremostId.eventId, name: "schedule", time: .at(100))
        }
    }
}
