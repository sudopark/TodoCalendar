//
//  AdExposureUsecase.swift
//  AdDomainInterface
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

public protocol AdExposureUsecase: Sendable {

    var isBannerAdAllowed: AnyPublisher<Bool, Never> { get }

    func shouldPreloadFullScreenAds() -> Bool

    func canExposeFullScreenAd(
        scope: FullScreenAdExposureRecord.Scope,
        isFromAppLaunch: Bool,
        at now: Date
    ) -> Bool

    func recordFullScreenAdExposed(scope: FullScreenAdExposureRecord.Scope, at now: Date)
}
