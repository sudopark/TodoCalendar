//
//  AIAgentCoordinatorViewModel.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - AIAgentCoordinatorViewModel

public protocol AIAgentCoordinatorViewModel: AnyObject, Sendable, AIAgentSceneInteractor {
    var listener: (any AIAgentSceneListener)? { get set }
}


// MARK: - AIAgentCoordinatorViewModelImple

public final class AIAgentCoordinatorViewModelImple: AIAgentCoordinatorViewModel, @unchecked Sendable {

    private let orchestrationUsecase: any AIAgentOrchestrationUsecase
    private let speechRecognizeUsecase: any SpeechRecognizeUsecase
    public weak var listener: (any AIAgentSceneListener)?
    var router: (any AIAgentRouting)?

    public init(
        orchestrationUsecase: any AIAgentOrchestrationUsecase,
        speechRecognizeUsecase: any SpeechRecognizeUsecase
    ) {
        self.orchestrationUsecase = orchestrationUsecase
        self.speechRecognizeUsecase = speechRecognizeUsecase
    }

    private var cancellables = Set<AnyCancellable>()
}


// MARK: - prepare

extension AIAgentCoordinatorViewModelImple {

    public func prepare() {
        self.orchestrationUsecase.state
            .sink(receiveValue: { [weak self] state in
                self?.notifyMode(for: state)
            })
            .store(in: &self.cancellables)
        self.orchestrationUsecase.restoreIfNeeded()
        self.orchestrationUsecase.loadUsage()
    }

    private func notifyMode(for state: AIAgentState) {
        let mode: AIAgentEntryMode
        switch state {
        case .idle:         mode = .idle
        case .processing:   mode = .command(.processing)
        case .confirm:      mode = .command(.needConfirm)
        case .done:         mode = .command(.done)
        case .failed:       mode = .command(.failed)
        }
        self.listener?.aiAgent(didChangeMode: mode)
    }
}


// MARK: - AIAgentSceneInteractor stubs (Phase 2~3 구현 예정)

extension AIAgentCoordinatorViewModelImple {

    public func enterVoiceInput() { }

    public func enterKeyboardInput() { }

    public func stopInput() { }

    public func submit(_ text: String) {
        self.orchestrationUsecase.sendCommand(text)
    }
}
