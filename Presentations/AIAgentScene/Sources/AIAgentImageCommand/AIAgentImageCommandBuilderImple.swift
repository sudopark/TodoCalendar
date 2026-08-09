//
//  AIAgentImageCommandBuilderImple.swift
//  AIAgentScene
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - AIAgentImageCommandBuilderImple

public final class AIAgentImageCommandBuilderImple: AIAgentImageCommandSceneBuilder {

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
    public func makeImageCommandScene(imageData: Data) -> any AIAgentImageCommandScene {
        let viewModel = AIAgentImageCommandViewModelImple(
            imageData: imageData,
            imageTextRecognizeService: self.usecaseFactory.imageTextRecognizeService,
            aiAgentOrchestrationUsecase: self.usecaseFactory.aiAgentOrchestrationUsecase,
            billingUsecase: self.usecaseFactory.billingUsecase
        )
        let viewController = AIAgentImageCommandViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        let router = AIAgentImageCommandRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
