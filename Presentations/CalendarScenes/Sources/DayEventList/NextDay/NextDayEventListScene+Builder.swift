//
//  NextDayEventListScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import CalendarPresentation


// MARK: - NextDayEventListScene

protocol NextDayEventListSceneInteractor: AnyObject {

    func nextDayChanged(_ nextDay: CurrentSelectDayModel, and eventsThatDay: [any CalendarEvent])
}
