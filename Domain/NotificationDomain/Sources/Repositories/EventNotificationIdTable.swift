//
//  EventNotificationIdTable.swift
//  NotificationDomain
//
//  Created by sudo.park on 1/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import NotificationDomainInterface


public typealias EventNotificationIdTable = EventNotificationIdTableV0

@Table("EventNotificationIds")
public struct EventNotificationIdTableV0 {
    
    @Column(.notNull, name: "event_id")
    public let eventId: String
    
    @Column(.notNull, name: "not_req_id")
    public let notificationReqId: String
}
