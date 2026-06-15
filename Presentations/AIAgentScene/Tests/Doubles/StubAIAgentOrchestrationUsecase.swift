//
//  StubAIAgentOrchestrationUsecase.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class StubAIAgentOrchestrationUsecase: AIAgentOrchestrationUsecase, @unchecked Sendable {

    // 실제 usecase처럼 nil 시작 — 상태 확정 전(복원 진행 중 등)엔 외부 무방출.
    let stateSubject = CurrentValueSubject<AIAgentState?, Never>(nil)
    let usageSubject = CurrentValueSubject<AIAgentUsage, Never>(.init(input: 0, output: 0, limit: 0))

    private(set) var didSendCommand: String?
    private(set) var didConfirm = false
    private(set) var didDecline = false
    private(set) var didReset = false
    private(set) var didRestore = false
    private(set) var didLoadUsage = false

    func sendCommand(_ text: String) {
        self.didSendCommand = text
        self.stateSubject.send(.processing(command: text))
    }
    func confirm() { self.didConfirm = true }
    func decline() { self.didDecline = true }
    func reset() { self.didReset = true; self.stateSubject.send(.idle) }
    func restoreIfNeeded() { self.didRestore = true }
    func loadUsage() { self.didLoadUsage = true }

    var state: AnyPublisher<AIAgentState, Never> {
        self.stateSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    var usage: AnyPublisher<AIAgentUsage, Never> {
        self.usageSubject.eraseToAnyPublisher()
    }
}
