//
//  AIAgentKeyboardInputBuilderImple.swift
//  AIAgentScene
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - AIAgentKeyboardInputBuilderImple

public final class AIAgentKeyboardInputBuilderImple: AIAgentKeyboardInputSceneBuilder {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance

    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }

    @MainActor
    public func makeKeyboardInputScene() -> any AIAgentKeyboardInputScene {
        let viewModel = AIAgentKeyboardInputViewModelImple(
            aiAgentOrchestrationUsecase: self.usecaseFactory.makeAIAgentOrchestrationUsecase()
        )
        let viewController = AIAgentKeyboardInputViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        let router = AIAgentKeyboardInputRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
