//
//  StoreKitService+Routing.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import StoreKitService


extension AppStoreReviewSheet: @retroactive AppStoreReviewRouter {

    @MainActor
    public func requestAppReview(in windowScene: UIWindowScene) {
        self.show(in: windowScene)
    }
}
