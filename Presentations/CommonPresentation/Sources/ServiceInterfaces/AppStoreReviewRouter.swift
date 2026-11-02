//
//  AppStoreReviewRouter.swift
//  CommonPresentation
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit


public protocol AppStoreReviewRouter: Sendable {

    @MainActor
    func requestAppReview(in windowScene: UIWindowScene)
}
