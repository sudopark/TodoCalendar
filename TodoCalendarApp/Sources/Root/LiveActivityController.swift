//
//  LiveActivityController.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


struct LiveActivityRegistration: Equatable {
    let target: LiveActivityTarget
    let content: EventCountdownActivityAttributes.State
}


protocol LiveActivityController: Sendable {
    /// ActivityKit 상태 관찰 시작 — 의존성 조립 시점이 아니라 앱이 준비된 뒤에 붙인다.
    func startObserving()
    func startActivity(
        _ target: LiveActivityTarget, _ content: EventCountdownActivityAttributes.State
    ) async throws
    func updateActivity(_ content: EventCountdownActivityAttributes.State) async
    func endActivity() async
    func currentActivity() async -> LiveActivityRegistration?

    var activityTargetUpdates: AnyPublisher<LiveActivityTarget?, Never> { get }
}
