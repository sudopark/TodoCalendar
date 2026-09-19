//
//  AICommandStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


enum AICommandStyleItem: String, WidgetStyleItem {

    case showExplain

    var settingKeyPath: WritableKeyPath<AICommandStyleSetting, Bool> {
        switch self {
        case .showExplain: return \.showExplain
        }
    }

    var name: String {
        switch self {
        case .showExplain:
            return "widget.style.aiCommand::showExplain".localized()
        }
    }
}
