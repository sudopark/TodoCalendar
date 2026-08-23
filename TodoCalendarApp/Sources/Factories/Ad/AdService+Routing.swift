//
//  AdService+Routing.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import CommonPresentation
import AdService


extension FullScreenAdRouterImple: @retroactive FullScreenAdRouter {

    @MainActor
    public func showFullScreenAd(
        from viewController: UIViewController,
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool
    ) {
        self.show(from: viewController, scope: scope, isFromAppLaunch: isFromAppLaunch)
    }
}

extension GoogleMobileAdsServiceImple: @retroactive PrivacyOptionsFormRouter { }
