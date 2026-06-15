//
//  AIAgentCommandViewModel.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


// MARK: - AIAgentCommandState

public enum AIAgentCommandState: Equatable, Sendable {
    case processing(command: String)
    case confirm(command: String, message: String?)
    case done(message: String?)
    case failed(reason: String?)
}


// MARK: - AIAgentCommandViewModelListener

protocol AIAgentCommandViewModelListener: AnyObject {
    func aiAgentCommandRequestClose()
}


// MARK: - AIAgentCommandViewModel

public protocol AIAgentCommandViewModel: AnyObject, Sendable {

    func sendCommand(_ text: String)
    func confirm()
    func decline()
    func restart()
    func close()

    var commandState: AnyPublisher<AIAgentCommandState?, Never> { get }
}


// MARK: - AIAgentCommandViewModelImple

final class AIAgentCommandViewModelImple: AIAgentCommandViewModel, @unchecked Sendable {

    private let orchestrationUsecase: any AIAgentOrchestrationUsecase
    weak var listener: (any AIAgentCommandViewModelListener)?

    init(orchestrationUsecase: any AIAgentOrchestrationUsecase) {
        self.orchestrationUsecase = orchestrationUsecase
    }
}


// MARK: - actions

extension AIAgentCommandViewModelImple {

    func sendCommand(_ text: String) {
        self.orchestrationUsecase.sendCommand(text)
    }

    func confirm() {
        self.orchestrationUsecase.confirm()
    }

    func decline() {
        self.orchestrationUsecase.decline()
    }

    func restart() {
        self.orchestrationUsecase.reset()
    }

    func close() {
        self.listener?.aiAgentCommandRequestClose()
    }
}


// MARK: - outputs

extension AIAgentCommandViewModelImple {

    var commandState: AnyPublisher<AIAgentCommandState?, Never> {
        return self.orchestrationUsecase.state
            .map { state in
                switch state {
                case .idle:
                    return nil
                case .processing(let command):
                    return .processing(command: command)
                case .confirm(let command, let message, _):
                    return .confirm(command: command, message: message)
                case .done(let message):
                    return .done(message: message)
                case .failed(let reason):
                    return .failed(reason: reason)
                }
            }
            .eraseToAnyPublisher()
    }
}
