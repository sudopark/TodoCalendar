//
//  SharePreviewViewController.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


final class SharePreviewViewController: UIHostingController<SharePreviewContainerView>, SharePreviewScene {

    private let viewModel: any SharePreviewViewModel
    let viewAppearance: ViewAppearance

    @MainActor
    var interactor: (any SharePreviewSceneInteractor)? { self.viewModel }

    init(
        viewModel: any SharePreviewViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = SharePreviewViewEventHandler()
        eventHandlers.bind(viewModel)
        let containerView = SharePreviewContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
            .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
