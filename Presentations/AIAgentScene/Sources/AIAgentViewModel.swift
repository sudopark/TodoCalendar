//
//  AIAgentViewModel.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Scenes
import Extensions


// MARK: - AIAgentStageKind

public enum AIAgentStageKind: Equatable, Sendable {
    case input
    case command
}


// MARK: - AIAgentViewModel

public protocol AIAgentViewModel: AnyObject, Sendable, AIAgentSceneInteractor {

    func prepare()

    var stage: AnyPublisher<AIAgentStageKind, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }

    var inputViewModel: any AIAgentInputViewModel { get }
    var commandViewModel: any AIAgentCommandViewModel { get }
}


// MARK: - AIAgentViewModelImple

public final class AIAgentViewModelImple: AIAgentViewModel, @unchecked Sendable {

    private let orchestrationUsecase: any AIAgentOrchestrationUsecase
    private let inputViewModelImple: AIAgentInputViewModelImple
    private let commandViewModelImple: AIAgentCommandViewModelImple
    var router: (any AIAgentRouting)?

    public init(
        orchestrationUsecase: any AIAgentOrchestrationUsecase,
        speechRecognizeUsecase: any SpeechRecognizeUsecase
    ) {
        self.orchestrationUsecase = orchestrationUsecase
        self.inputViewModelImple = AIAgentInputViewModelImple(
            speechRecognizeUsecase: speechRecognizeUsecase
        )
        self.commandViewModelImple = AIAgentCommandViewModelImple(
            orchestrationUsecase: orchestrationUsecase
        )
        self.inputViewModelImple.listener = self
        self.commandViewModelImple.listener = self
    }

    private let stageSubject = CurrentValueSubject<AIAgentStageKind?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()
}


// MARK: - lifecycle / stage 분기

extension AIAgentViewModelImple {

    public func prepare() {
        self.orchestrationUsecase.loadUsage()
        self.orchestrationUsecase.state
            .sink(receiveValue: { [weak self] state in
                guard let self else { return }
                if case .idle = state {
                    self.stageSubject.send(.input)
                    self.inputViewModelImple.startInput()
                } else {
                    self.stageSubject.send(.command)
                    self.inputViewModelImple.stopInput()
                }
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - AIAgentInputViewModelListener

extension AIAgentViewModelImple: AIAgentInputViewModelListener {

    func aiAgentInput(didComplete text: String) {
        self.commandViewModelImple.sendCommand(text)
    }

    func aiAgentInputRequestSystemSetting() {
        self.router?.openSystemSetting()
    }

    func aiAgentInput(didFail error: any Error) {
        self.router?.showError(error)
    }
}


// MARK: - AIAgentCommandViewModelListener

extension AIAgentViewModelImple: AIAgentCommandViewModelListener {

    func aiAgentCommandRequestClose() {
        self.inputViewModelImple.stopInput()
        self.router?.closeScene()
    }
}


// MARK: - outputs

extension AIAgentViewModelImple {

    public var stage: AnyPublisher<AIAgentStageKind, Never> {
        return self.stageSubject.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    public var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.orchestrationUsecase.usage
    }

    public var inputViewModel: any AIAgentInputViewModel {
        return self.inputViewModelImple
    }

    public var commandViewModel: any AIAgentCommandViewModel {
        return self.commandViewModelImple
    }
}
