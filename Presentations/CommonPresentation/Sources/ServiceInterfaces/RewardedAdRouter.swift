//
//  RewardedAdRouter.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


public protocol RewardedAdRouter {

    @MainActor
    func showRewardedAd(
        from viewController: UIViewController,
        completion: @escaping (RewardedAdResult) -> Void
    )
}
