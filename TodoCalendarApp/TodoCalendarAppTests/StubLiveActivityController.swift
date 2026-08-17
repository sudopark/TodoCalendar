//
//  StubLiveActivityController.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

import Domain

@testable import TodoCalendarApp


final class StubLiveActivityController: LiveActivityController, @unchecked Sendable {

    private let stubRestoredRegistration: LiveActivityRegistration?
    private let stubStartError: (any Error)?
    /// 실제 ActivityKit이 `end()` 직후 `activityStateUpdates`로 종료를 알리는 것을 흉내낸다 —
    /// 교체 흐름 중 도착하는 stale nil 레이스(F3) 재현용.
    private let stubEmitsNilOnEnd: Bool
    /// 겹친 `startActivity` 호출을 재현하려고 `Activity.request`의 지연을 흉내낸다 (I-3 회귀).
    private let stubStartDelayNanoseconds: UInt64
    let activityTargetUpdatesSubject: CurrentValueSubject<LiveActivityTarget?, Never>

    var didStartWith: (LiveActivityTarget, EventCountdownActivityAttributes.State)?
    var didUpdateWith: EventCountdownActivityAttributes.State?
    var didEnd: Bool = false
    var didCheckCurrentActivity: Bool = false
    var didStartObserving: Bool = false

    init(
        stubRestoredRegistration: LiveActivityRegistration? = nil,
        stubStartError: (any Error)? = nil,
        stubEmitsNilOnEnd: Bool = false,
        stubStartDelayNanoseconds: UInt64 = 0
    ) {
        self.stubRestoredRegistration = stubRestoredRegistration
        self.stubStartError = stubStartError
        self.stubEmitsNilOnEnd = stubEmitsNilOnEnd
        self.stubStartDelayNanoseconds = stubStartDelayNanoseconds
        self.activityTargetUpdatesSubject = .init(nil)
    }

    func startObserving() {
        self.didStartObserving = true
    }

    func startActivity(
        _ target: LiveActivityTarget, _ content: EventCountdownActivityAttributes.State
    ) async throws {
        if self.stubStartDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: self.stubStartDelayNanoseconds)
        }
        self.didStartWith = (target, content)
        if let stubStartError {
            throw stubStartError
        }
    }

    func updateActivity(_ content: EventCountdownActivityAttributes.State) async {
        self.didUpdateWith = content
    }

    func endActivity() async {
        self.didEnd = true
        if self.stubEmitsNilOnEnd {
            self.activityTargetUpdatesSubject.send(nil)
        }
    }

    func currentActivity() async -> LiveActivityRegistration? {
        self.didCheckCurrentActivity = true
        return self.stubRestoredRegistration
    }

    var activityTargetUpdates: AnyPublisher<LiveActivityTarget?, Never> {
        return self.activityTargetUpdatesSubject.eraseToAnyPublisher()
    }
}
