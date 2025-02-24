//
//  ForemostEventUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions


public protocol ForemostEventUsecase: Sendable {
    
    func refresh()
    func update(foremost eventId: ForemostEventId) async throws
    func remove() async throws
    
    var foremostEvent: AnyPublisher<(any ForemostMarkableEvent)?, Never> { get }
}

public final class ForemostEventUsecaseImple: ForemostEventUsecase, @unchecked Sendable {
    
    private let repository: any ForemostEventRepository
    private let sharedDataStore: SharedDataStore
    private let eventNotifyService: SharedEventNotifyService
    
    public init(
        repository: any ForemostEventRepository,
        sharedDataStore: SharedDataStore,
        eventNotifyService: SharedEventNotifyService
    ) {
        self.repository = repository
        self.sharedDataStore = sharedDataStore
        self.eventNotifyService = eventNotifyService
    }
    
    private var cancellables: Set<AnyCancellable> = []
}

extension ForemostEventUsecaseImple {
    
    public func refresh() {
        
        let handleRefreshed: ((any ForemostMarkableEvent)?) -> Void = { [weak self] event in
            guard let event
            else {
                self?.updateForemostEventId(nil)
                return
            }
            
            let eventId = ForemostEventId(event: event)
            self?.updateForemostEventId(eventId)
            self?.updateForemostEvent(event)
        }
        
        self.repository.foremostEvent()
            .handleNotify(self.eventNotifyService) {
                $0 ? RefreshingEvent.refreshForemostEvent(true) : .refreshForemostEvent(false)
            }
            .sink(receiveValue: handleRefreshed)
            .store(in: &self.cancellables)
    }
    
    public func update(foremost eventId: ForemostEventId) async throws {
        let event = try await self.repository.updateForemostEvent(eventId)
        let eventId = ForemostEventId(event: event)
        self.updateForemostEventId(eventId)
        self.updateForemostEvent(event)
    }
    
    public func remove() async throws {
        try await self.repository.removeForemostEvent()
        self.updateForemostEventId(nil)
    }
    
    private func updateForemostEventId(_ eventId: ForemostEventId?) {
        let key = ShareDataKeys.foremostEventId.rawValue
        if let eventId {
            self.sharedDataStore.put(ForemostEventId.self, key: key, eventId)
        } else {
            self.sharedDataStore.delete(key)
        }
    }
    
    private func updateForemostEvent(_ event: (any ForemostMarkableEvent)) {
     
        switch event {
        case let todo as TodoEvent:
            self.sharedDataStore.updateTodo(todo)
        case let schedule as ScheduleEvent:
            self.sharedDataStore.updateSchedule(schedule)
        default: break
        }
    }
}

extension ForemostEventUsecaseImple {
    
    public var foremostEvent: AnyPublisher<(any ForemostMarkableEvent)?, Never> {
        
        let selectSource: (ForemostEventId?) -> AnyPublisher<(any ForemostMarkableEvent)?, Never>
        selectSource = { [weak self] id in
            guard let self = self
            else {
                return Empty().eraseToAnyPublisher()
            }
            
            switch id?.eventId {
            case .some(let eventId) where id?.isTodo == true:
                return self.sharedDataStore.todo(eventId)
            case .some(let eventId) where id?.isTodo == false:
                return self.sharedDataStore.schedule(eventId)
            default:
                return Just(nil).eraseToAnyPublisher()
            }
        }
        
        return self.sharedDataStore
            .observe(ForemostEventId.self, key: ShareDataKeys.foremostEventId.rawValue)
            .map(selectSource)
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}

private extension SharedDataStore {
    
    func updateTodo(_ todo: TodoEvent) {
        let dataKey = ShareDataKeys.todos.rawValue
        self.update([String: TodoEvent].self, key: dataKey) {
            ($0 ?? [:]) |> key(todo.uuid) .~ todo
        }
    }
    
    func updateSchedule(_ schedule: ScheduleEvent) {
        let dataKey = ShareDataKeys.schedules.rawValue
        self.update(MemorizedEventsContainer<ScheduleEvent>.self, key: dataKey) {
            ($0 ?? .init()).append(schedule)
        }
    }
    
    func todo(_ id: String) -> AnyPublisher<(any ForemostMarkableEvent)?, Never> {
        let dataKey = ShareDataKeys.todos.rawValue
        return self.observe([String: TodoEvent].self, key: dataKey)
            .map { $0?[id] }
            .eraseToAnyPublisher()
    }
    
    func schedule(_ id: String) -> AnyPublisher<(any ForemostMarkableEvent)?, Never> {
        let dataKey = ShareDataKeys.schedules.rawValue
        return self.observe(MemorizedEventsContainer<ScheduleEvent>.self, key: dataKey)
            .map { $0?.evnet(id) }
            .eraseToAnyPublisher()
    }
}
