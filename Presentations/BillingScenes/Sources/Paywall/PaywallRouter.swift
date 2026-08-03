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

// 전용 라우팅 메서드는 없다 — 공통 메서드(showError·showToast·closeScene·showConfirm·openSafari)로 전부 처리된다
protocol PaywallRouting: Routing, Sendable, AnyObject { }


// MARK: - PaywallRouter

final class PaywallRouter: BaseRouterImple, PaywallRouting, @unchecked Sendable { }
