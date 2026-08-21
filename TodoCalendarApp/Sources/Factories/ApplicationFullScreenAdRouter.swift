//
//  ApplicationFullScreenAdRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import AdService


final class ApplicationFullScreenAdRouter: FullScreenAdRouter {
    
    private let fullScreenAd: FullScreenAd
    
    init(adUnitId: String) {
        self.fullScreenAd = FullScreenAd(adUnitId: adUnitId)
    }
    
    @MainActor
    func showFullScreenAd(from viewController: UIViewController) async throws {
        try await self.fullScreenAd.show(from: viewController)
    }
}
