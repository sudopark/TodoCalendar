//
//  ApplicationPrivacyOptionsFormRouter.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import AdService


final class ApplicationPrivacyOptionsFormRouter: PrivacyOptionsFormRouter {
    
    private let adService: GoogleMobileAdsServiceImple
    
    init(adService: GoogleMobileAdsServiceImple) {
        self.adService = adService
    }
    
    @MainActor
    func isPrivacyOptionsRequired() -> Bool {
        return self.adService.isPrivacyOptionsRequired()
    }
    
    @MainActor
    func showPrivacyOptionsForm(from viewController: UIViewController) async throws {
        try await self.adService.showPrivacyOptionsForm(from: viewController)
    }
}
