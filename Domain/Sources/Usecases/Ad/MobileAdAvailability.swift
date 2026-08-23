//
//  MobileAdAvailability.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol MobileAdAvailability: Sendable {

    var isStarted: AnyPublisher<Bool, Never> { get }
    var isStartedNow: Bool { get }
}
