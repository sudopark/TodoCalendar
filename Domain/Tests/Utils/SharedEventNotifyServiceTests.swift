//
//  SharedEventNotifyServiceTests.swift
//  DomainTests
//
//  Created by sudo.park on 3/2/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import UnitTestHelpKit
import Extensions

@testable import Domain


class SharedEventNotifyServiceTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    
    private func makeService() -> SharedEventNotifyService {
        return .init(notifyQueue: nil)
    }
    
    struct DummyEvent1: SharedEvent { }
    struct DummyEvent2: SharedEvent { }
}

extension SharedEventNotifyServiceTests {
    
    @Test func service_notifyEvent() async throws {
        // given
        let expect = expectConfirm("전파된 이벤트 수신")
        expect.count = 2
        let service = self.makeService()
        
        // when
        service.notify(RefreshingEvent.refreshingTodo(true))
        
        let eventSource: AnyPublisher<RefreshingEvent, Never> = service.event()
        let events = try await self.outputs(expect, for: eventSource) {
            service.notify(RefreshingEvent.refreshingTodo(false))
            service.notify(DummyEvent1())
            service.notify(DummyEvent2())
            service.notify(RefreshingEvent.refreshForemostEvent(true))
        }
        
        // then
        #expect(events == [
            .refreshingTodo(false),
            .refreshForemostEvent(true)
        ])
    }
}
