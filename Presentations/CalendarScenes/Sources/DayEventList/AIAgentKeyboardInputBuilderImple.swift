//
//  AIAgentKeyboardInputBuilderImple.swift
//  CalendarScenes
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - AIAgentKeyboardInputBuilderImple

final class AIAgentKeyboardInputBuilderImple: AIAgentKeyboardInputSceneBuilder {

    private let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    private let viewAppearance: ViewAppearance

    init(
        aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase,
        viewAppearance: ViewAppearance
    ) {
        self.aiAgentOrchestrationUsecase = aiAgentOrchestrationUsecase
        self.viewAppearance = viewAppearance
    }

    @MainActor
    func makeScene() -> any AIAgentKeyboardInputScene {
        let viewModel = AIAgentKeyboardInputViewModelImple(
            aiAgentOrchestrationUsecase: self.aiAgentOrchestrationUsecase
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
