//
//  StubSpeechRecognizeUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 6/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


public final class StubSpeechRecognizeUsecase: SpeechRecognizeUsecase, @unchecked Sendable {

    public let recognizeResultSubject = PassthroughSubject<Result<String, any Error>, Never>()
    public let recognizingTextSubject = CurrentValueSubject<String, Never>("")
    public let levelSubject = CurrentValueSubject<Float?, Never>(nil)

    public private(set) var didStartListening = false
    public private(set) var didStopListening = false
    public private(set) var didFinishListening = false

    public init() {}

    public func startListening() { self.didStartListening = true }
    public func stopListening() { self.didStopListening = true }
    public func finishListening() { self.didFinishListening = true }

    public var recognizeResult: AnyPublisher<Result<String, any Error>, Never> {
        self.recognizeResultSubject.eraseToAnyPublisher()
    }
    public var recognizingText: AnyPublisher<String, Never> {
        self.recognizingTextSubject.eraseToAnyPublisher()
    }
    public var isRecognizingWithLevel: AnyPublisher<Float?, Never> {
        self.levelSubject.eraseToAnyPublisher()
    }
}
