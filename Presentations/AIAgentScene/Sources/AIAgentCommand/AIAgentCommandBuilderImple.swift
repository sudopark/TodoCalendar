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
    private let paywallSceneBuilder: any PaywallSceneBuilder

    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        paywallSceneBuilder: any PaywallSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.paywallSceneBuilder = paywallSceneBuilder
    }

    @MainActor
    public func makeCommandScene() -> any AIAgentCommandScene {
        let viewModel = AIAgentCommandViewModelImple(
            orchestrationUsecase: self.usecaseFactory.aiAgentOrchestrationUsecase,
            billingUsecase: self.usecaseFactory.billingUsecase
        )
        let viewController = AIAgentCommandViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        let router = AIAgentRouter(paywallSceneBuilder: self.paywallSceneBuilder)
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
