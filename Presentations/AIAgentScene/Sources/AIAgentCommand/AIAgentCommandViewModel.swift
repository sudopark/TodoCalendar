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


// MARK: - AIAgentCommandViewModel

public protocol AIAgentCommandViewModel: AnyObject, Sendable {

    func sendCommand(_ text: String)
    func confirm()
    func decline()
    func cancel()
    func close()

    var commandState: AnyPublisher<AIAgentCommandState?, Never> { get }
}


// MARK: - AIAgentCommandViewModelImple

final class AIAgentCommandViewModelImple: AIAgentCommandViewModel, @unchecked Sendable {

    private let orchestrationUsecase: any AIAgentOrchestrationUsecase
    var router: (any AIAgentRouting)?

    init(orchestrationUsecase: any AIAgentOrchestrationUsecase) {
        self.orchestrationUsecase = orchestrationUsecase
    }
}


// MARK: - actions

extension AIAgentCommandViewModelImple {

    func sendCommand(_ text: String) {
        try? self.orchestrationUsecase.submit(text)
    }

    func confirm() {                       // 처리 계속 — 시트 유지
        self.orchestrationUsecase.confirm()
    }

    func decline() {                       // confirm 거부 → reject + idle
        self.orchestrationUsecase.decline()
        self.router?.closeScene()
    }

    func cancel() {                        // 진행 중 중지 → reset(서버 cancel API) + idle
        self.orchestrationUsecase.reset()
        self.router?.closeScene()
    }

    func close() {                         // 숨김 — 상태 보존, 재진입 가능
        self.router?.closeScene()
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
                case .listening:
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
