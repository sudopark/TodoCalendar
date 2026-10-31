//
//  ForemostEventUsecaseImple.swift
//  EventDomain
//
//  Created by sudo.park on 6/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions
import EventDomainInterface
import KernelUtils

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
    
    private let cancellables = CancelBag()
}

extension ForemostEventUsecaseImple {
    
    public func refresh() {
        
        let handleRefreshed: ((any ForemostMarkableEvent)?) -> Void = { [weak self] event in
            guard let event
            else {
                self?.updateForemostEventId(nil)
                return
            }
            
            // 본문을 id 보다 먼저 싣는다 — id 가 먼저 닿으면 본문 조회가 일시적으로 nil 을 방출한다
            self?.updateForemostEvent(event)
            self?.updateForemostEventId(ForemostEventId(event: event))
        }
        
        self.repository.foremostEvent()
            .handleNotify(self.eventNotifyService) {
                $0 ? RefreshingEvent.refreshForemostEvent(true) : .refreshForemostEvent(false)
            }
            .sink(receiveValue: handleRefreshed)
            .store(in: self.cancellables)
    }
    
    public func update(foremost eventId: ForemostEventId) async throws {
        self.updateMarkingStatus(.marking(evnetId: eventId.eventId))
        defer { self.updateMarkingStatus(.idle) }
        let event = try await self.repository.updateForemostEvent(eventId)
        self.updateForemostEvent(event)
        self.updateForemostEventId(ForemostEventId(event: event))
    }
    
    public func remove() async throws {
        self.updateMarkingStatus(.unmarking)
        defer { self.updateMarkingStatus(.idle) }
        try await self.repository.removeForemostEvent()
        self.updateForemostEventId(nil)
    }
    
    private func updateMarkingStatus(_ newStatus: ForemostMarkingStatus) {
        self.sharedDataStore.put(ForemostMarkingStatus.self, key: ShareDataKeys.foremostMarkingStatus.rawValue, newStatus)
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
    
    public var foremostEventMarkingStatus: AnyPublisher<ForemostMarkingStatus, Never> {
        return self.sharedDataStore
            .observe(
                ForemostMarkingStatus.self, key: ShareDataKeys.foremostMarkingStatus.rawValue
            )
            .compactMap { $0 }
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
            .removeDuplicates()
            .map { $0 as (any ForemostMarkableEvent)? }
            .eraseToAnyPublisher()
    }
    
    func schedule(_ id: String) -> AnyPublisher<(any ForemostMarkableEvent)?, Never> {
        let dataKey = ShareDataKeys.schedules.rawValue
        return self.observe(MemorizedEventsContainer<ScheduleEvent>.self, key: dataKey)
            .map { $0?.evnet(id) }
            .removeDuplicates()
            .map { $0 as (any ForemostMarkableEvent)? }
            .eraseToAnyPublisher()
    }
}
