//
//  AdViewBuilder.swift
//  CommonPresentation
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Domain


public protocol AdViewBuilder {

    @MainActor
    func makeBannerView(size: AdBannerSize) -> any View

    @MainActor
    func makeBannerUIView(size: AdBannerSize) -> UIView
}
