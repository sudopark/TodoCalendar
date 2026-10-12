//
//  WidgetStyleEditRouter.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


protocol WidgetStyleEditRouting: Routing {

    func showPaidFeatureAdGuide(
        _ reason: PaidFeatureGateFailReason, onFinished: @escaping @Sendable (Bool) -> Void
    )

    func routeToPhotoPick(onPick: @escaping @Sendable (Data?) -> Void)
}

final class WidgetStyleEditRouter: BaseRouterImple, WidgetStyleEditRouting, @unchecked Sendable {

    // 시스템 피커가 delegate 를 weak 으로 잡아 호출측이 붙들고 있어야 한다
    private let imagePicker: ImagePicker = .init()
    private let adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder

    init(adGuideSceneBuilder: any PaidFeatureAdGuideSceneBuilder) {
        self.adGuideSceneBuilder = adGuideSceneBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
    
    private var currentScene: (any WidgetStyleEditScene)? {
        self.scene as? (any WidgetStyleEditScene)
    }
}


extension WidgetStyleEditRouter {

    func routeToPhotoPick(onPick: @escaping @Sendable (Data?) -> Void) {
        Task { @MainActor in
            let picker = self.imagePicker.makeViewController(source: .photoLibrary) { data in
                onPick(data)
            }
            self.scene?.present(picker, animated: true)
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
