//
//  PrivacyOptionsFormRouter.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit


public protocol PrivacyOptionsFormRouter: Sendable {
    
    @MainActor
    func isPrivacyOptionsRequired() -> Bool
    
    @MainActor
    func showPrivacyOptionsForm(from viewController: UIViewController) async throws
}
