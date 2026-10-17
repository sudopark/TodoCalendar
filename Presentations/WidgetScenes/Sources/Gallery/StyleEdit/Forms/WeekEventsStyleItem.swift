//
//  WeekEventsStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


enum WeekEventsStyleItem: String, WidgetStyleItem {

    case showWeekDayHeader

    var settingKeyPath: WritableKeyPath<WeekEventsStyleSetting, Bool> {
        switch self {
        case .showWeekDayHeader: return \.showWeekDayHeader
        }
    }

    var name: String {
        switch self {
        case .showWeekDayHeader:
            return "widget.style.weekEvents::showWeekDayHeader".localized()
        }
    }
}
