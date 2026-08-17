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
    func showShareSheet(text: String)
    func showShareSheet(imageContent: ShareImageContentModel, headerText: String)
}


// MARK: - Router

final class SharePreviewRouter: BaseRouterImple, SharePreviewRouting, @unchecked Sendable {

    func showShareSheet(imageContent: ShareImageContentModel, headerText: String) {
        Task { @MainActor in
            guard let appearance = self.scene?.viewAppearance, let sceneWidth = self.scene?.view.bounds.width
            else { return }

            let cardWidth = sceneWidth - Metric.Spacing.regular * 2
            let card = ShareImageCardView(headerText: headerText, content: imageContent, cardWidth: cardWidth)
                .environment(appearance)

            let renderer = ImageRenderer(content: card)
            renderer.scale = UIScreen.main.scale

            guard let uiImage = renderer.uiImage else { return }

            self.showShareSheet(image: uiImage)
        }
    }
}
