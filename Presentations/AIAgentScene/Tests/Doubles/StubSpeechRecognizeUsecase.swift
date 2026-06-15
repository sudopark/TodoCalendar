//
//  StubSpeechRecognizeUsecase.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class StubSpeechRecognizeUsecase: SpeechRecognizeUsecase, @unchecked Sendable {

    let recognizeResultSubject = PassthroughSubject<Result<String, any Error>, Never>()
    let recognizingTextSubject = CurrentValueSubject<String, Never>("")
    let levelSubject = CurrentValueSubject<Float?, Never>(nil)

    private(set) var didStartListening = false
    private(set) var didStopListening = false
    private(set) var didFinishListening = false

    func startListening() { self.didStartListening = true }
    func stopListening() { self.didStopListening = true }
    func finishListening() { self.didFinishListening = true }

    var recognizeResult: AnyPublisher<Result<String, any Error>, Never> {
        self.recognizeResultSubject.eraseToAnyPublisher()
    }
    var recognizingText: AnyPublisher<String, Never> {
        self.recognizingTextSubject.eraseToAnyPublisher()
    }
    var isRecognizingWithLevel: AnyPublisher<Float?, Never> {
        self.levelSubject.eraseToAnyPublisher()
    }
}
