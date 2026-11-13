//
//  SelectGoogleCalendarDialogRouter.swift
//  SettingScene
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import SceneInfra


// MARK: - Routing

protocol SelectGoogleCalendarDialogRouting: Routing, Sendable { }


// MARK: - Router

final class SelectGoogleCalendarDialogRouter: BaseRouterImple, SelectGoogleCalendarDialogRouting, @unchecked Sendable { }
