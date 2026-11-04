//
//  AppStoreReviewSheet.swift
//  StoreKitService
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import StoreKit


public struct AppStoreReviewSheet: Sendable {

    public init() { }

    @MainActor
    public func show(in scene: UIWindowScene) {
        AppStore.requestReview(in: scene)
    }
}
