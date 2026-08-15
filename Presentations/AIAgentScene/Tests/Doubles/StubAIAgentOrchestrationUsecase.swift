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
    let recognizingTextSubject = PassthroughSubject<String, Never>()
    let voiceLevelSubject = PassthroughSubject<Float, Never>()
    let speechPermissionDeniedSubject = PassthroughSubject<Void, Never>()
    private(set) var didPrepare = false
    private(set) var didEnterVoiceInput = false
    private(set) var didFinishVoiceInput = false
    private(set) var didEnterKeyboardInput = false
    private(set) var didEnterImageInput = false
    private(set) var didStopInput = false
    private(set) var didSubmit: String?
    private(set) var didSubmitImageCommandWith: (text: String, instruction: String?)?
    private(set) var didConfirm = false
    private(set) var didDecline = false
    private(set) var didReset = false
    private(set) var didRestore = false
    private(set) var didLoadUsageCount = 0
    var didLoadUsage: Bool { self.didLoadUsageCount > 0 }

    var stubSubmitError: (any Error)?
    var stubImageSubmitError: (any Error)?
    var isCreditExhausted: Bool = false

    func prepare() { self.didPrepare = true }
    func enterVoiceInput() {
        self.didEnterVoiceInput = true
    }
    func finishVoiceInput() { self.didFinishVoiceInput = true }
    func enterKeyboardInput() {
        self.didEnterKeyboardInput = true
    }
    func enterImageInput() {
        self.didEnterImageInput = true
    }
    func stopInput() { self.didStopInput = true }
    func submit(_ text: String) throws {
        if let stubSubmitError { throw stubSubmitError }
        self.didSubmit = text
        self.stateSubject.send(.processing(command: text))
    }
    func submitImageCommand(text: String, additionalInstruction: String?) throws {
        if let stubImageSubmitError { throw stubImageSubmitError }
        self.didSubmitImageCommandWith = (text, additionalInstruction)
        self.stateSubject.send(.processing(command: text))
    }
    func confirm() { self.didConfirm = true }
    func decline() { self.didDecline = true }
    func reset() { self.didReset = true; self.stateSubject.send(.idle) }
    func restoreIfNeeded() { self.didRestore = true }
    func loadUsage() { self.didLoadUsageCount += 1 }

    private(set) var didHandleJobStatusChangedWith: String?
    func handleJobStatusChanged(_ jobId: String) {
        self.didHandleJobStatusChangedWith = jobId
    }

    private(set) var didRefreshProcessingJob = false
    func refreshProcessingJobIfNeeded() {
        self.didRefreshProcessingJob = true
    }

    var state: AnyPublisher<AIAgentState, Never> {
        self.stateSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    var usage: AnyPublisher<AIAgentUsage, Never> {
        self.usageSubject.eraseToAnyPublisher()
    }
    var recognizingText: AnyPublisher<String, Never> {
        self.recognizingTextSubject.eraseToAnyPublisher()
    }
    var voiceLevel: AnyPublisher<Float, Never> {
        self.voiceLevelSubject.eraseToAnyPublisher()
    }
    var speechPermissionDenied: AnyPublisher<Void, Never> {
        self.speechPermissionDeniedSubject.eraseToAnyPublisher()
    }
}
