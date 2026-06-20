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
    public func makeInlineComponent(listener: any AIAgentSceneListener) -> AIAgentInlineComponent {
        let coordinator = AIAgentCoordinatorViewModelImple(
            orchestrationUsecase: self.orchestrationUsecase,
            speechRecognizeUsecase: self.speechRecognizeUsecase
        )
        coordinator.listener = listener
        let router = AIAgentRouter()
        coordinator.router = router
        return AIAgentInlineComponent(interactor: coordinator)
    }
}
