//
//  AIAgentCommandBuilderImple.swift
//  AIAgentScene
//

import UIKit
import Domain
import Scenes
import CommonPresentation


public final class AIAgentCommandBuilderImple: AIAgentCommandSceneBuilder {

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
    public func makeCommandScene() -> any AIAgentCommandScene {
        let viewModel = AIAgentCommandViewModelImple(
            orchestrationUsecase: self.usecaseFactory.makeAIAgentOrchestrationUsecase()
        )
        let viewController = AIAgentCommandViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        let router = AIAgentRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
