//
//  TodayAndNextStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


enum TodayAndNextStyleItem: String, WidgetStyleItem {

    case showTimeZone

    var settingKeyPath: WritableKeyPath<TodayAndNextStyleSetting, Bool> {
        switch self {
        case .showTimeZone: return \.showTimeZone
        }
    }

    var name: String {
        switch self {
        case .showTimeZone:
            return "widget.style.todayAndNext::showTimeZone".localized()
        }
    }
}
