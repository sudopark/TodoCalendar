//
//  UISceneSession+LaunchSource.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit


extension UISceneSession {

    private var launchedFromAppIconKey: String { "isLaunchedFromAppIcon" }

    var isLaunchedFromAppIcon: Bool {
        get { self.userInfo?[self.launchedFromAppIconKey] as? Bool ?? false }
        set {
            var info = self.userInfo ?? [:]
            info[self.launchedFromAppIconKey] = newValue
            self.userInfo = info
        }
    }
}
