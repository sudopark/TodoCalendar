//
//  AdViewBuilder.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI


public enum AdBannerPlacement: Sendable {
    case calendarBottom
    case aiCommandProcessing
}

public protocol AdViewBuilder {
    
    @MainActor
    func makeBannerView(for placement: AdBannerPlacement) -> any View
    
    @MainActor
    func makeBannerUIView(for placement: AdBannerPlacement) -> UIView
}
