//
//  EventNotificationUsecase.swift
//  NotificationDomainInterface
//
//  Created by sudo.park on 1/14/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import AsyncAlgorithms
import Extensions

public protocol EventNotificationUsecase: AnyObject, Sendable {

    func runSyncEventNotification()
}
