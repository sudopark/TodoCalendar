//
//  EventNotificationIdTable.swift
//  Repository
//
//  Created by sudo.park on 1/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros


typealias EventNotificationIdTable = EventNotificationIdTableV0

@Table("EventNotificationIds")
struct EventNotificationIdTableV0 {
    
    @Column(.notNull, name: "event_id")
    let eventId: String
    
    @Column(.notNull, name: "not_req_id")
    let notificationReqId: String
}
