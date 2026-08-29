//
//  SettingNavigationController.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit


// MARK: - SettingNavigationController

final class SettingNavigationController: UINavigationController {

    var onDismissed: (@MainActor () -> Void)?

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard self.isBeingDismissed else { return }
        self.onDismissed?()
    }
}
