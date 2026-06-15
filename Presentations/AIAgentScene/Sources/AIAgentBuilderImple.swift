//
//  AIAgentBuilderImple.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


public final class AIAgentBuilderImple {

    private let orchestrationUsecase: any AIAgentOrchestrationUsecase
    private let speechRecognizeUsecase: any SpeechRecognizeUsecase
    private let viewAppearance: ViewAppearance

    public init(
        orchestrationUsecase: any AIAgentOrchestrationUsecase,
        speechRecognizeUsecase: any SpeechRecognizeUsecase,
        viewAppearance: ViewAppearance
    ) {
        self.orchestrationUsecase = orchestrationUsecase
        self.speechRecognizeUsecase = speechRecognizeUsecase
        self.viewAppearance = viewAppearance
    }
}

extension AIAgentBuilderImple: AIAgentSceneBuilder {

    @MainActor
    public func makeAIAgentScene() -> any AIAgentScene {
        let viewModel = AIAgentViewModelImple(
            orchestrationUsecase: self.orchestrationUsecase,
            speechRecognizeUsecase: self.speechRecognizeUsecase
        )
        let viewController = AIAgentViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        let router = AIAgentRouter()
        router.scene = viewController
        viewModel.router = router
        return viewController
    }
}
