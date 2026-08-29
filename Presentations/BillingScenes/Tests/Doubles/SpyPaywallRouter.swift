//
//  SpyPaywallRouter.swift
//  BillingScenesTests
//
//  Created by sudo.park on 8/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Scenes
import TestDoubles

@testable import BillingScenes


final class SpyPaywallRouter: BaseSpyRouter, PaywallRouting, @unchecked Sendable {

    var didShowManageSubscriptions: Bool { self.didShowManageSubscriptionsWithDismissed != nil }
    var didShowManageSubscriptionsWithDismissed: (@Sendable () -> Void)?

    func showManageSubscriptions(_ dismissed: @escaping @Sendable () -> Void) {
        self.didShowManageSubscriptionsWithDismissed = dismissed
    }
}
