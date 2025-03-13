//
//  EventDetailBasicData.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/6/23.
//

import Foundation
import Domain

struct EventDetailBasicData: Equatable {
    var name: String?
    var originEventTime: EventTime?
    var selectedTime: SelectedTime?
    var eventRepeating: EventRepeatingTimeSelectResult?
    var eventTagId: EventTagId
    var eventNotifications: [EventNotificationTimeOption]
    let excludeTimes: Set<String>
    
    init() {
        self.eventTagId = .default
        self.eventNotifications = []
        self.excludeTimes = []
    }
    
    init(
        name: String?,
        selectedTime: SelectedTime? = nil,
        eventRepeating: EventRepeatingTimeSelectResult? = nil,
        eventTagId: EventTagId,
        eventNotifications: [EventNotificationTimeOption] = [],
        excludeTimes: Set<String> = []
    ) {
        self.name = name
        self.selectedTime = selectedTime
        self.eventRepeating = eventRepeating
        self.eventTagId = eventTagId
        self.eventNotifications = eventNotifications
        self.excludeTimes = excludeTimes
    }
}
