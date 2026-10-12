//
//  ColorThemeEditRouter.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol ColorThemeEditRouting: Routing, Sendable {

    func showPaidFeatureAdGuide(
        _ reason: PaidFeatureGateFailReason, onFinished: @escaping @Sendable (Bool) -> Void
    )
}

// MARK: - Router

final class ColorThemeEditRouter: BaseRouterImple, ColorThemeEditRouting, @unchecked Sendable {

    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder

    init(adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder) {
        self.adGuideSceneBuilder = adGuideSceneBuilder
    }

    override func closeScene(animate: Bool, _ dismissed: (@Sendable () -> Void)?) {
        Task { @MainActor in
            self.scene?.navigationController?.popViewController(animated: animate)
            dismissed?()
        }
    }

    func showPaidFeatureAdGuide(
        _ reason: PaidFeatureGateFailReason, onFinished: @escaping @Sendable (Bool) -> Void
    ) {
        Task { @MainActor in
            let guide = self.adGuideSceneBuilder.makePaidFeatureAdGuideScene(
                reason: reason, onFinished: onFinished, onUseDefault: nil
            )
            self.showBottomSlide(guide)
        }
    }
}
