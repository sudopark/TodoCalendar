//
//  EventLiveActivityUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol EventLiveActivityUsecase: Sendable {

    func startActivity(_ target: LiveActivityTarget) async throws
    func stopActivity() async
    func prepare() async
    func handleWillEnterForeground() async

    var registeredTarget: AnyPublisher<LiveActivityTarget?, Never> { get }
}
