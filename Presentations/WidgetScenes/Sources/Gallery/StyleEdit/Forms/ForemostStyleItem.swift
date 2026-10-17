//
//  ForemostStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


enum ForemostStyleItem: String, WidgetStyleItem {

    case showTypeLabel

    var settingKeyPath: WritableKeyPath<ForemostStyleSetting, Bool> {
        switch self {
        case .showTypeLabel: return \.showTypeLabel
        }
    }

    var name: String {
        switch self {
        case .showTypeLabel:
            return "widget.style.foremost::showTypeLabel".localized()
        }
    }
}
