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
    private let adViewBuilder: (any AdViewBuilder)?

    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        adViewBuilder: (any AdViewBuilder)?
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.adViewBuilder = adViewBuilder
    }

    @MainActor
    public func makeCommandScene(
        listener: (any AIAgentCommandSceneListener)?
    ) -> any AIAgentCommandScene {
        let viewModel = AIAgentCommandViewModelImple(
            orchestrationUsecase: self.usecaseFactory.aiAgentOrchestrationUsecase,
            billingUsecase: self.usecaseFactory.billingUsecase
        )
        viewModel.listener = listener
        let viewController = AIAgentCommandViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance,
            adViewBuilder: self.adViewBuilder
        )
        let router = AIAgentRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
