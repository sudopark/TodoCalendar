//
//  EventCellViewModel+Registration.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import CalendarPresentation


extension EventCellViewModel {

    func ddayCandidateRegistrationApplied(_ candidates: [DDayCandidate]) -> any EventCellViewModel {
        guard let schedule = self as? ScheduleEventCellViewModel else { return self }
        return schedule
            |> \.isDDayCandidateRegistered .~ candidates.contains(schedule.ddayCandidate)
    }

    func liveActivityRegistrationApplied(_ registered: LiveActivityTarget?) -> any EventCellViewModel {
        switch self {
        case let todo as TodoEventCellViewModel:
            return todo |> \.isLiveActivityRegistered .~ (registered != nil && todo.liveActivityTarget == registered)
        case let schedule as ScheduleEventCellViewModel:
            return schedule |> \.isLiveActivityRegistered .~ (registered != nil && schedule.liveActivityTarget == registered)
        case let holiday as HolidayEventCellViewModel:
            return holiday |> \.isLiveActivityRegistered .~ (registered != nil && holiday.liveActivityTarget == registered)
        case let apple as AppleCalendarEventCellViewModel:
            return apple |> \.isLiveActivityRegistered .~ (registered != nil && apple.liveActivityTarget == registered)
        case let google as GoogleCalendarEventCellViewModel:
            return google |> \.isLiveActivityRegistered .~ (registered != nil && google.liveActivityTarget == registered)
        default:
            return self
        }
    }
}
