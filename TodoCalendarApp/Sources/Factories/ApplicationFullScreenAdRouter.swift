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
    private let gate: AdDisplayGate

    init(adUnitId: String, gate: AdDisplayGate) {
        self.fullScreenAd = FullScreenAd(adUnitId: adUnitId)
        self.gate = gate
    }

    @MainActor
    func showFullScreenAd(from viewController: UIViewController) async throws {
        // 게이팅은 에러가 아니라 정상적인 "안 띄움" — throw 하지 않는다
        guard self.gate.canShowAdNow else { return }
        try await self.fullScreenAd.show(from: viewController)
    }
}
