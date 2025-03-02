//
//  SharedEventNotifyService.swift
//  Domain
//
//  Created by sudo.park on 3/2/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - SharedEvent

public protocol SharedEvent: Sendable { }

public enum RefreshingEvent: SharedEvent, Equatable {
    case refreshingTodo(Bool)
    case refreshingSchedule(Bool)
    case refreshingCurrentTodo(Bool)
    case refreshingUncompletedTodo(Bool)
    case refreshForemostEvent(Bool)
}


// MARK: - SharedEventNotifyService

public final class SharedEventNotifyService: @unchecked Sendable {
    
    private let notifyQueue: DispatchQueue?
    private let notifySubject = PassthroughSubject<any SharedEvent, Never>()
    
    public init(
        notifyQueue: DispatchQueue? = DispatchQueue(label: "serial-event-notify-queue")
    ) {
        self.notifyQueue = notifyQueue
    }
}

extension SharedEventNotifyService {
    
    func notify(_ event: any SharedEvent) {
        if let queue = self.notifyQueue {
            queue.async { self.notifySubject.send(event) }
        } else {
            self.notifySubject.send(event)
        }
    }
    
    func event<E: SharedEvent>() -> AnyPublisher<E, Never> {
        return self.notifySubject
            .compactMap { $0 as? E }
            .eraseToAnyPublisher()
    }
}


extension Publisher {
    
    func handleNotify(
        _ notifyService: SharedEventNotifyService,
        _ eventSelectorWhetherRefreshing: @Sendable @escaping (Bool) -> any SharedEvent
    ) -> Publishers.HandleEvents<Self> {
        
        return self
            .handleEvents(
                receiveSubscription: { _ in
                    notifyService.notify(eventSelectorWhetherRefreshing(true))
                },
                receiveCompletion: { _ in
                    notifyService.notify(eventSelectorWhetherRefreshing(false))
                }
            )
    }
}
