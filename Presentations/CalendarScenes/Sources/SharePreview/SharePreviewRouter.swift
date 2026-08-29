//
//  SharePreviewRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SharePreviewRouting: Routing, Sendable {
    func shareText(_ text: String)
    func shareImage(_ content: ShareImageContentModel, headerText: String)
}


// MARK: - Router

final class SharePreviewRouter: BaseRouterImple, SharePreviewRouting, @unchecked Sendable {

    private enum Constant {
        static let shareScopeIdentifier: String = "eventShare"
    }

    private let fullScreenAdRouter: (any FullScreenAdRouter)?

    init(fullScreenAdRouter: (any FullScreenAdRouter)?) {
        self.fullScreenAdRouter = fullScreenAdRouter
        super.init()
    }

    func shareText(_ text: String) {
        self.showShareSheet(text: text, onShared: { [weak self] in
            self?.presentFullScreenAdIfPossible()
        })
    }

    func shareImage(_ content: ShareImageContentModel, headerText: String) {
        Task { @MainActor in
            guard let appearance = self.scene?.viewAppearance, let sceneWidth = self.scene?.view.bounds.width
            else { return }

            let cardWidth = sceneWidth - Metric.Spacing.regular * 2
            let card = ShareImageCardView(headerText: headerText, content: content, cardWidth: cardWidth)
                .environment(appearance)

            let renderer = ImageRenderer(content: card)
            renderer.scale = UIScreen.main.scale

            guard let uiImage = renderer.uiImage else { return }

            self.showShareSheet(image: uiImage, onShared: { [weak self] in
                self?.presentFullScreenAdIfPossible()
            })
        }
    }

    @MainActor
    private func presentFullScreenAdIfPossible() {
        guard let scene = self.scene, let adRouter = self.fullScreenAdRouter else { return }
        adRouter.showFullScreenAd(
            from: scene, scope: .service(identifier: Constant.shareScopeIdentifier), isFromAppLaunch: false
        )
    }
}
