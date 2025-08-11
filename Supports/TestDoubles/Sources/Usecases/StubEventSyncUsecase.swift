//
//  StubEventSyncUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 8/11/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


open class StubEventSyncUsecase: EventSyncUsecase, @unchecked Sendable {
    
    public init() { }
    
    public var didSyncRequested: Bool = false
    private let isSyncSubject = CurrentValueSubject<Bool, Never>(false)
    
    open func sync() {
        self.isSyncSubject.send(true)
        self.didSyncRequested = true
        self.isSyncSubject.send(false)
    }
    
    open var isSyncInProgress: AnyPublisher<Bool, Never> {
        return self.isSyncSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
