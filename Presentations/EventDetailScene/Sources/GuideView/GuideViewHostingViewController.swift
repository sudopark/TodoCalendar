//
//  GuideViewHostingViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 9/8/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation

protocol GuideScene: Scenes.Scene { }

protocol GuideSceneBuilder {
    
    @MainActor
    func makeTodoEventGuide() -> any GuideScene
    
    @MainActor
    func makeForemostEventGuide() -> any GuideScene
}

final class GuideViewRouter: BaseRouterImple { }

final class GuideSceneBuilderImple: GuideSceneBuilder {
    
    let viewAppearance: ViewAppearance
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    @MainActor
    func makeTodoEventGuide() -> any GuideScene {
        let router = GuideViewRouter()
        let guideView = TodoEventGuideView(appearance: self.viewAppearance)
            .eventHandler(\.onClose) { [weak router] in
                router?.closeScene()
            }
        let viewController = GuideViewHostingViewController(guideView, router, self.viewAppearance)
        router.scene = viewController
        return viewController
    }
    
    @MainActor
    func makeForemostEventGuide() -> any GuideScene {
        let router = GuideViewRouter()
        let guideView = ForemostEventGuideView(appearance: self.viewAppearance)
            .eventHandler(\.onClose) { [weak router] in
                router?.closeScene()
            }
        let viewController = GuideViewHostingViewController(guideView, router, self.viewAppearance)
        router.scene = viewController
        return viewController
    }
}

final class GuideViewHostingViewController<GuideView: View>: UIHostingController<GuideView>, GuideScene {
    typealias Interactor = EmptyInteractor
    var interactor: EmptyInteractor?
    let viewAppearance: ViewAppearance
    private let router: GuideViewRouter

    init(_ guideView: GuideView, _ router: GuideViewRouter, _ viewAppearance: ViewAppearance) {
        self.router = router
        self.viewAppearance = viewAppearance
        super.init(rootView: guideView)
        self.view.backgroundColor = .clear
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
