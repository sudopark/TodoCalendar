//
//  FullScreenAdRouter.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain


public protocol FullScreenAdRouter {

    @MainActor
    func showFullScreenAd(
        from viewController: UIViewController,
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool
    )
}
