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
import Extensions


public protocol EventNotificationUsecase: AnyObject, Sendable {
    
    func runSyncEventNotification()
}


public final class EventNotificationUsecaseImple: EventNotificationUsecase, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let todoEventUsecase: any TodoEventUsecase
    private let scheduleEventUescase: any ScheduleEventUsecase
    private let notificationRepository: any EventNotificationRepository
    private let notificationService: any LocalNotificationService
    
    private var cancellables: Set<AnyCancellable> = []
    private var todoSyncBinding: AnyCancellable?
    private var scheduleSyncBinding: AnyCancellable?
    
    private let serialWorkQueue = DispatchQueue(label: "event-notification-sync")
    
    public init(
        calendarSettingUsecase: any CalendarSettingUsecase,
        todoEventUsecase: any TodoEventUsecase,
        scheduleEventUescase: any ScheduleEventUsecase,
        notificationRepository: any EventNotificationRepository,
        notificationService: any LocalNotificationService = UNUserNotificationCenter.current()
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.todoEventUsecase = todoEventUsecase
        self.scheduleEventUescase = scheduleEventUescase
        self.notificationRepository = notificationRepository
        self.notificationService = notificationService
    }
}


extension EventNotificationUsecaseImple {
    
    public func runSyncEventNotification() {
        
        let runSyncNotifications: (TimeZone) -> Void = { [weak self] timeZone in
            self?.runSyncTodoEvents(timeZone)
            self?.runSyncScheduleEvents(timeZone)
        }
        
        self.calendarSettingUsecase.currentTimeZone
            .subscribe(on: self.serialWorkQueue)
            .sink(receiveValue: runSyncNotifications)
            .store(in: &self.cancellables)
    }
    
    private func fromNowToNextYearPeriod() -> Range<TimeInterval> {
        let now = Date(); let nextYear = now.addingTimeInterval(3600*24*365)
        return now.timeIntervalSince1970..<nextYear.timeIntervalSince1970
    }
    
    private func runSyncTodoEvents(_ timeZone: TimeZone) {
        
        self.todoSyncBinding?.cancel()
        
        self.todoSyncBinding = self.todoEventUsecase.todoEvents(in: self.fromNowToNextYearPeriod())
            .scan(EventChanges<TodoEvent>()) { $0.update($1) { $0.uuid } }
            .sink(receiveValue: { [weak self] changes in
                self?.syncTodoEventNotifications(timeZone, changes)
            })
    }
    
    private func syncTodoEventNotifications(
        _ timeZone: TimeZone,
        _ changes: EventChanges<TodoEvent>
    ) {
        Task { [weak self] in
            guard let self = self else { return }
            let shouldUpdateIds = changes.changed.values.map { $0.uuid }
            let removedIds = changes.removed.values.map { $0.uuid }
            let pendingNotificationIds = try await self.notificationRepository
                .removeAllSavedNotificationId(of: shouldUpdateIds + removedIds)
            self.cancelNotifications(pendingNotificationIds)
            
            let params = changes.changed.values.compactMap { todo -> SingleEventNotificationMakeParams? in
                guard let option = todo.notificationOption else { return nil }
                return .init(todo: todo, in: timeZone, timeOption: option)
            }
            
            await params.asyncForEach { param in
                if let notificationId = try? await self.scheduleNotification(param) {
                    do {
                        try await self.notificationRepository.saveNotificationId(of: param.eventId, notificationId)
                    } catch {
                        self.cancelNotifications([notificationId])
                    }
                }
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func runSyncScheduleEvents(_ timeZone: TimeZone) {
        
        self.scheduleSyncBinding?.cancel()
        
        self.scheduleSyncBinding = self.scheduleEventUescase.scheduleEvents(in: self.fromNowToNextYearPeriod())
            .scan(EventChanges<ScheduleEvent>()) { $0.update($1) { $0.uuid } }
            .sink(receiveValue: { [weak self] changes in
                self?.syncScheduleEventNotifications(timeZone, changes)
            })
    }
    
    
    private func syncScheduleEventNotifications(
        _ timeZone: TimeZone,
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
            let params = eventAndRepeatTimes.compactMap { pair -> SingleEventNotificationMakeParams? in
                guard let oprion = pair.0.notificationOption else { return nil }
                return .init(schedule: pair.0, repeatingAt: pair.1.time, in: timeZone, with: oprion)
            }
            
            await params.asyncForEach { param in
                if let notificationId = try? await self.scheduleNotification(param) {
                    do {
                        try await self.notificationRepository.saveNotificationId(of: param.eventId, notificationId)
                    } catch {
                        self.cancelNotifications([notificationId])
                    }
                }
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func scheduleNotification(_ params: SingleEventNotificationMakeParams) async throws -> String {
        let content = UNMutableNotificationContent()
            |> \.title .~ params.eventName
            |> \.body .~ params.eventTimeText
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: params.scheduleDateComponents, repeats: false
        )
        
        let uuid = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuid, content: content, trigger: trigger)
        
        try await self.notificationService.add(request)
        return uuid
    }
    
    private func cancelNotifications(_ ids: [String]) {
        self.notificationService.removePendingNotificationRequests(withIdentifiers: ids)
    }
}


private struct EventChanges<T: Equatable> {
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
