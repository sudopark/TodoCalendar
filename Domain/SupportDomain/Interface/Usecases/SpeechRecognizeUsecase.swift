//
//  SpeechRecognizeUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - SpeechRecognizeResult

// 텍스트 없이 끝나는 종료(침묵 타임아웃·오디오 입력 끊김)도 소비자가 인지해야 하므로
// completion이 아니라 명시적 값으로 방출한다.

public enum SpeechRecognizeResult: Sendable, Equatable {
    case recognized(String)
    case endedWithoutRecognizing
}


// MARK: - SpeechRecognizeUsecase

public protocol SpeechRecognizeUsecase: Sendable {

    func startListening()
    func stopListening()
    func finishListening()

    var recognizeResult: AnyPublisher<Result<SpeechRecognizeResult, any Error>, Never> { get }
    var recognizingText: AnyPublisher<String, Never> { get }
    var isRecognizingWithLevel: AnyPublisher<Float?, Never> { get }
}
