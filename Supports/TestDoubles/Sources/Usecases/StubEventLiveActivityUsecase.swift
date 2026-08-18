//
//  StubEventLiveActivityUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


open class StubEventLiveActivityUsecase: EventLiveActivityUsecase, @unchecked Sendable {

    public init(registeredTarget: LiveActivityTarget? = nil) {
        self.registeredTargetSubject = .init(registeredTarget)
    }

    public let registeredTargetSubject: CurrentValueSubject<LiveActivityTarget?, Never>
    public var stubStartError: (any Error)?

    public var didStartTarget: LiveActivityTarget?
    public var didStartTargetCallback: ((LiveActivityTarget) -> Void)?
    open func startActivity(_ target: LiveActivityTarget) async throws {
        self.didStartTarget = target
        self.didStartTargetCallback?(target)
        if let error = self.stubStartError { throw error }
        self.registeredTargetSubject.send(target)
    }

    public var didStopActivity: Bool = false
    public var didStopActivityCallback: (() -> Void)?
    open func stopActivity() async {
        self.didStopActivity = true
        self.didStopActivityCallback?()
        self.registeredTargetSubject.send(nil)
    }

    public var didPrepare: Bool = false
    open func prepare() async {
        self.didPrepare = true
    }

    public var didHandleWillEnterForeground: Bool = false
    open func handleWillEnterForeground() async {
        self.didHandleWillEnterForeground = true
    }

    public var registeredTarget: AnyPublisher<LiveActivityTarget?, Never> {
        return self.registeredTargetSubject.eraseToAnyPublisher()
    }
}
