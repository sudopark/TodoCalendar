//
//  EventCountdownLiveActivityController.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
@preconcurrency import ActivityKit
import Domain


final class EventCountdownLiveActivityController: LiveActivityController, @unchecked Sendable {

    private let targetUpdatesSubject = CurrentValueSubject<LiveActivityTarget?, Never>(nil)
    private var isObserving = false
}


// MARK: - LiveActivityController

extension EventCountdownLiveActivityController {

    func startObserving() {
        guard self.isObserving == false else { return }
        self.isObserving = true
        self.watchExistingActivities()
        self.watchNewActivities()
    }

    /// 등록 요청 직전에 살아있는 액티비티를 전부 종료해 "동시 1개"를 진실 원천(`Activity.activities`)
    /// 에서 강제한다 — usecase의 자체 장부가 겹친 호출로 어긋나도 여기서 막힌다.
    func startActivity(
        _ target: LiveActivityTarget, _ content: EventCountdownActivityAttributes.State
    ) async throws {
        await self.endAllAliveActivities()

        let attributes = EventCountdownActivityAttributes(target: target.asEventTarget)
        let activityContent = ActivityContent(state: content, staleDate: content.eventDate)
        let activity = try Activity<EventCountdownActivityAttributes>.request(
            attributes: attributes, content: activityContent, pushType: nil
        )
        self.watchDismissal(of: activity)
    }

    func updateActivity(_ content: EventCountdownActivityAttributes.State) async {
        guard let activity = self.aliveActivity()
        else { return }
        let activityContent = ActivityContent(state: content, staleDate: content.eventDate)
        await activity.update(activityContent)
    }

    func endActivity() async {
        guard let activity = self.aliveActivity()
        else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    func currentActivity() async -> LiveActivityRegistration? {
        return self.currentRegistration()
    }

    var activityTargetUpdates: AnyPublisher<LiveActivityTarget?, Never> {
        return self.targetUpdatesSubject.eraseToAnyPublisher()
    }
}


// MARK: - 액티비티 등록 상태 감시

extension EventCountdownLiveActivityController {

    /// `.ended`·`.dismissed`도 dismiss 전까진 `activities`에 남는다.
    private func aliveActivities() -> [Activity<EventCountdownActivityAttributes>] {
        return Activity<EventCountdownActivityAttributes>.activities.filter {
            $0.activityState != .ended && $0.activityState != .dismissed
        }
    }

    private func aliveActivity() -> Activity<EventCountdownActivityAttributes>? {
        return self.aliveActivities().first
    }

    private func currentTarget() -> LiveActivityTarget? {
        return self.aliveActivity()?.attributes.target.asDomainTarget
    }

    private func currentRegistration() -> LiveActivityRegistration? {
        guard let activity = self.aliveActivity()
        else { return nil }
        return LiveActivityRegistration(
            target: activity.attributes.target.asDomainTarget,
            content: activity.content.state
        )
    }

    private func endAllAliveActivities() async {
        for activity in self.aliveActivities() {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func watchExistingActivities() {
        Activity<EventCountdownActivityAttributes>.activities.forEach { self.watchDismissal(of: $0) }
    }

    /// `Activity.activityUpdates`는 새로 생성되는 액티비티만 흘려보낸다.
    private func watchNewActivities() {
        Task { [weak self] in
            for await activity in Activity<EventCountdownActivityAttributes>.activityUpdates {
                guard let self else { return }
                self.targetUpdatesSubject.send(self.currentTarget())
                self.watchDismissal(of: activity)
            }
        }
    }

    private func watchDismissal(of activity: Activity<EventCountdownActivityAttributes>) {
        Task { [weak self] in
            for await state in activity.activityStateUpdates {
                guard let self else { return }
                guard state == .dismissed || state == .ended else { continue }
                self.targetUpdatesSubject.send(self.currentTarget())
            }
        }
    }
}


// MARK: - LiveActivityTarget ↔ LiveActivityEventTarget

extension LiveActivityTarget {

    var asEventTarget: LiveActivityEventTarget {
        switch self {
        case .todo(let id):
            return .todo(id: id)
        case .schedule(let id, let turnKey):
            return .schedule(id: id, turnKey: turnKey)
        case .holiday(let uuid, let dateString):
            return .holiday(uuid: uuid, dateString: dateString)
        case .googleCalendar(let accountId, let calendarId, let eventId):
            return .googleCalendar(accountId: accountId, calendarId: calendarId, eventId: eventId)
        case .appleCalendar(let calendarId, let eventId):
            return .appleCalendar(calendarId: calendarId, eventId: eventId)
        }
    }
}

extension LiveActivityEventTarget {

    var asDomainTarget: LiveActivityTarget {
        switch self {
        case .todo(let id):
            return .todo(id: id)
        case .schedule(let id, let turnKey):
            return .schedule(id: id, turnKey: turnKey)
        case .holiday(let uuid, let dateString):
            return .holiday(uuid: uuid, dateString: dateString)
        case .googleCalendar(let accountId, let calendarId, let eventId):
            return .googleCalendar(accountId: accountId, calendarId: calendarId, eventId: eventId)
        case .appleCalendar(let calendarId, let eventId):
            return .appleCalendar(calendarId: calendarId, eventId: eventId)
        }
    }
}
