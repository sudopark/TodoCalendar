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
    private let foremostIdSubject = CurrentValueSubject<ForemostEventId?, Never>(nil)
    public init(foremostId: ForemostEventId? = nil) {
        self.initialForemostID = foremostId
    }
    
    open func refresh() {
        self.foremostIdSubject.send(self.initialForemostID)
    }
    
    open func update(foremost eventId: ForemostEventId) async throws {
        self.foremostIdSubject.send(eventId)
    }
    
    open func remove() async throws {
        self.foremostIdSubject.send(nil)
    }
    
    open var foremostEventId: AnyPublisher<ForemostEventId?, Never> {
        return self.foremostIdSubject
            .eraseToAnyPublisher()
    }
}
