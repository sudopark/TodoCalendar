//
//  EventNotificationUsecase.swift
//  Domain
//
//  Created by sudo.park on 1/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import UserNotifications
import Prelude
import Optics
import AsyncAlgorithms
import Extensions


public protocol EventNotificationUsecase: AnyObject, Sendable {
    
    func runSyncEventNotification()
}


public final class EventNotificationUsecaseImple: EventNotificationUsecase, @unchecked Sendable {
    
    private let todoEventUsecase: any TodoEventUsecase
    private let scheduleEventUescase: any ScheduleEventUsecase
    private let notificationRepository: any EventNotificationRepository
    private let notificationService: any LocalNotificationService
    
    private var cancellables: Set<AnyCancellable> = []
    private var todoSyncBinding: AnyCancellable?
    private var scheduleSyncBinding: AnyCancellable?
    
    private let serialWorkQueue = DispatchQueue(label: "event-notification-sync")
    
    public init(
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUescase: any ScheduleEventUsecase,
        notificationRepository: any EventNotificationRepository,
        notificationService: any LocalNotificationService = UNUserNotificationCenter.current()
    ) {
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUescase = scheduleEventUescase
        self.notificationRepository = notificationRepository
        self.notificationService = notificationService
    }
}


extension EventNotificationUsecaseImple {
    
    public func runSyncEventNotification() {
        
        self.runSyncTodoEvents()
        self.runSyncScheduleEvents()
    }
    
    private func fromNowToNextYearPeriod() -> Range<TimeInterval> {
        let now = Date(); let nextYear = now.addingTimeInterval(3600*24*365)
        return now.timeIntervalSince1970..<nextYear.timeIntervalSince1970
    }
    
    private func runSyncTodoEvents() {
        
        self.todoSyncBinding?.cancel()
        
        self.todoSyncBinding = self.todoEventUsecase.todoEvents(in: self.fromNowToNextYearPeriod())
            .scan(EventChanges<TodoEvent>()) { $0.update($1) { $0.uuid } }
            .sink(receiveValue: { [weak self] changes in
                self?.syncTodoEventNotifications(changes)
            })
    }
    
    private func syncTodoEventNotifications(
        _ changes: EventChanges<TodoEvent>
    ) {
        Task { [weak self] in
            guard let self = self else { return }
            let shouldUpdateIds = changes.changed.values.map { $0.uuid }
            let removedIds = changes.removed.values.map { $0.uuid }
            let pendingNotificationIds = try await self.notificationRepository
                .removeAllSavedNotificationId(of: shouldUpdateIds + removedIds)
            self.cancelNotifications(pendingNotificationIds)
            
            let params = changes.changed.values.flatMap { todo -> [SingleEventNotificationMakeParams] in
                return todo.notificationOptions.compactMap {
                    return SingleEventNotificationMakeParams(todo: todo, timeOption: $0)
                }
            }
            
            let eventAndNotificationIds = await params.async.reduce(into: [String: [String]]()) { acc, param in
                if let notificationId = try? await self.scheduleNotificationIfFuture(param) {
                    let newIds = (acc[param.eventId] ?? []) + [notificationId]
                    acc[param.eventId] = newIds
                }
            }
            do {
                try await self.notificationRepository.batchSaveNotificationId(eventAndNotificationIds)
            } catch {
                let notificationIds = eventAndNotificationIds.flatMap { $0.value }
                self.cancelNotifications(notificationIds)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func runSyncScheduleEvents() {
        
        self.scheduleSyncBinding?.cancel()
        
        self.scheduleSyncBinding = self.scheduleEventUescase.scheduleEvents(in: self.fromNowToNextYearPeriod())
            .scan(EventChanges<ScheduleEvent>()) { $0.update($1) { $0.uuid } }
            .sink(receiveValue: { [weak self] changes in
                self?.syncScheduleEventNotifications(changes)
            })
    }
    
    
    private func syncScheduleEventNotifications(
        _ changes: EventChanges<ScheduleEvent>
    ) {
        Task { [weak self] in
            guard let self = self else { return }
            let shouldUpdateIds = changes.changed.values.map { $0.uuid }
            let removeIds = changes.removed.values.map { $0.uuid }
            let pendingNotificationIds = try await self.notificationRepository
                .removeAllSavedNotificationId(of: shouldUpdateIds + removeIds)
            self.cancelNotifications(pendingNotificationIds)
            
            let eventAndRepeatTimes = changes.changed.values.flatMap { event in
                return event.repeatingTimes.map { (event, $0) }
            }
            let params = eventAndRepeatTimes.flatMap { pair -> [SingleEventNotificationMakeParams] in
                return pair.0.notificationOptions.compactMap {
                    return SingleEventNotificationMakeParams(
                        schedule: pair.0, repeatingAt: pair.1.time, with: $0
                    )
                }
            }
            
            let eventAndNotificationIds = await params.async.reduce(into: [String: [String]]()) { acc, param in
                if let notificationId = try? await self.scheduleNotificationIfFuture(param) {
                    let newIds = (acc[param.eventId] ?? []) + [notificationId]
                    acc[param.eventId] = newIds
                }
            }
            do {
                try await self.notificationRepository.batchSaveNotificationId(eventAndNotificationIds)
            } catch {
                let notificationIds = eventAndNotificationIds.flatMap { $0.value }
                self.cancelNotifications(notificationIds)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func scheduleNotificationIfFuture(_ params: SingleEventNotificationMakeParams) async throws -> String? {
        let content = UNMutableNotificationContent()
            |> \.title .~ params.eventName
            |> \.body .~ params.eventTimeText
        
        guard let trigger = params.scheduleTime.trigger(from: Date())
        else { return nil }
        
        let uuid = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuid, content: content, trigger: trigger)
        
        try await self.notificationService.add(request)
        return uuid
    }
    
    private func cancelNotifications(_ ids: [String]) {
        self.notificationService.removePendingNotificationRequests(withIdentifiers: ids)
    }
}


private struct EventChanges<T: Equatable>: @unchecked Sendable {
    var changed: [String: T] = [:]
    var origin: [String: T] = [:]
    var removed: [String: T] = [:]
    
    func update(_ events: [T], _ keySelector: (T) -> String) -> Self {
        let newOriginMap = events.asDictionary { keySelector($0) }
        let added = newOriginMap.filter { origin[$0.key] == nil }
        let removed = origin.filter { newOriginMap[$0.key] == nil }
        let updated = newOriginMap
            .compactMap { pair in origin[pair.key].map { (pair.value, $0 )} }
            .filter { $0.0 != $0.1 }
            .map { $0.0 }
            .asDictionary { keySelector($0) }
        
        return EventChanges<T>()
            |> \.changed .~ added.merging(updated) { $1 }
            |> \.origin .~ newOriginMap
            |> \.removed .~ removed
    }
}


private extension SingleEventNotificationMakeParams.ScheduleTime {
    
    func trigger(from now: Date) -> UNNotificationTrigger? {
        switch self {
        case .at(let time):
            let interval = time - now.timeIntervalSince1970
            guard interval > 0 else { return nil }
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            
        case .components(let components):
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
    }
}
