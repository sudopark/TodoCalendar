//
//  EventNotificationTimeOption.swift
//  Domain
//
//  Created by sudo.park on 1/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public enum EventNotificationTimeOption: Sendable, Equatable {
    
    case atTime
    case before(seconds: TimeInterval)
    case allDay9AM
    case allDay12AM
    case allDay9AMBefore(seconds: TimeInterval)
}
