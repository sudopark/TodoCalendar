//
//  AIAgentKeyboardInputViewController.swift
//  AIAgentScene
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


final class AIAgentKeyboardInputViewController: UIHostingController<AIAgentKeyboardInputContainerView>,
                                                AIAgentKeyboardInputScene {

    var interactor: (any AIAgentKeyboardInputSceneInteractor)? { nil }

    private let viewModel: any AIAgentKeyboardInputViewModel
    private let viewAppearance: ViewAppearance

    init(
        viewModel: any AIAgentKeyboardInputViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandler = AIAgentKeyboardInputEventHandler()
        eventHandler.bind(viewModel)
        var containerView = AIAgentKeyboardInputContainerView(
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
