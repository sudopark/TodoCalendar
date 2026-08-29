//
//  AppStoreSubscriptionSheet.swift
//  StoreKitService
//
//  Created by sudo.park on 8/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import StoreKit


public struct AppStoreSubscriptionSheet: Sendable {

    public init() { }

    @MainActor
    public func show(in scene: UIWindowScene) async throws {
        try await AppStore.showManageSubscriptions(in: scene)
    }
}
