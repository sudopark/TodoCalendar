//
//  StubAIAgentOrchestrationUsecase.swift
//  TestDoubles
//

import Foundation
import Combine
import Domain


public final class StubAIAgentOrchestrationUsecase: AIAgentOrchestrationUsecase, @unchecked Sendable {

    public let stateSubject = CurrentValueSubject<AIAgentState?, Never>(nil)
    public let usageSubject = CurrentValueSubject<AIAgentUsage, Never>(.init(input: 0, output: 0, limit: 0))
    public let recognizingTextSubject = PassthroughSubject<String, Never>()
    public let voiceLevelSubject = PassthroughSubject<Float, Never>()
    public private(set) var didPrepare: Bool?
    public private(set) var didEnterVoiceInput: Bool?
    public private(set) var didFinishVoiceInput: Bool?
    public private(set) var didEnterKeyboardInput: Bool?
    public private(set) var didStopInput: Bool?
    public private(set) var didSubmit: String?

    public init() {}

    public func prepare() { self.didPrepare = true }
    public func enterVoiceInput() { self.didEnterVoiceInput = true }
    public func finishVoiceInput() { self.didFinishVoiceInput = true }
    public func enterKeyboardInput() { self.didEnterKeyboardInput = true }
    public func stopInput() { self.didStopInput = true }
    public func submit(_ text: String) throws { self.didSubmit = text }
    public func confirm() {}
    public func decline() {}
    public func reset() { self.stateSubject.send(.idle) }
    public func restoreIfNeeded() {}
    public func loadUsage() {}

    public var state: AnyPublisher<AIAgentState, Never> {
        self.stateSubject.compactMap { $0 }.eraseToAnyPublisher()
    }
    public var usage: AnyPublisher<AIAgentUsage, Never> {
        self.usageSubject.eraseToAnyPublisher()
    }
    public var recognizingText: AnyPublisher<String, Never> {
        self.recognizingTextSubject.eraseToAnyPublisher()
    }
    public var voiceLevel: AnyPublisher<Float, Never> {
        self.voiceLevelSubject.eraseToAnyPublisher()
    }
}
