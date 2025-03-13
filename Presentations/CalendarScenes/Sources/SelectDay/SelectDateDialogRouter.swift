//
//  SelectDateDialogRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 3/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Scenes


protocol SelectDayDialogRouting: Routing, Sendable { }


final class SelectDayDialogRouter: BaseRouterImple, SelectDayDialogRouting, @unchecked Sendable { }
