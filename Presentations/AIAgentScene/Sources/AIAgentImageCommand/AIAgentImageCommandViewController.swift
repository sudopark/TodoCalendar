//
//  AIAgentImageCommandViewController.swift
//  AIAgentScene
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


final class AIAgentImageCommandViewController: UIHostingController<AIAgentImageCommandContainerView>,
                                                AIAgentImageCommandScene {

    var interactor: (any AIAgentImageCommandSceneInteractor)? { nil }

    private let viewModel: any AIAgentImageCommandViewModel
    private let viewAppearance: ViewAppearance

    init(
        viewModel: any AIAgentImageCommandViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandler = AIAgentImageCommandEventHandler()
        eventHandler.bind(viewModel)
        var containerView = AIAgentImageCommandContainerView(
            viewAppearance: viewAppearance,
            eventHandler: eventHandler
        )
        containerView.stateBinding = { $0.bind(viewModel) }
        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
