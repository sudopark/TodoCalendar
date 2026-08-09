//
//  PaywallRouter.swift
//  BillingScenes
//
//  Created by sudo.park on 8/3/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes


// MARK: - PaywallRouting

protocol PaywallRouting: Routing, Sendable, AnyObject { }


// MARK: - PaywallRouter

final class PaywallRouter: BaseRouterImple, PaywallRouting, @unchecked Sendable { }
