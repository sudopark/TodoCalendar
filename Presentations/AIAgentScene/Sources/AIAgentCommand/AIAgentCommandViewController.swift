//
//  AIAgentCommandViewController.swift
//  AIAgentScene
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


final class AIAgentCommandViewController: UIHostingController<AIAgentCommandStageContainerView>,
                                          AIAgentCommandScene {

    var interactor: (any AIAgentCommandSceneInteractor)? { nil }

    private let viewModel: any AIAgentCommandViewModel
    private let viewAppearance: ViewAppearance

    init(
        viewModel: any AIAgentCommandViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = AIAgentCommandViewEventHandler()
        eventHandlers.bind(viewModel)
        var containerView = AIAgentCommandStageContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        containerView.stateBinding = { $0.bind(viewModel) }
        super.init(rootView: containerView)
        self.view.backgroundColor = .clear
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
