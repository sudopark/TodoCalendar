//
//  AdService+Routing.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import AdService


extension FullScreenAd: @retroactive FullScreenAdRouter {

    @MainActor
    public func showFullScreenAd(from viewController: UIViewController) async throws {
        try await self.show(from: viewController)
    }
}

extension GoogleMobileAdsServiceImple: @retroactive PrivacyOptionsFormRouter { }
