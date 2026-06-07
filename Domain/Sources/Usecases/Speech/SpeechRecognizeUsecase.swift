//
//  SpeechRecognizeUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - SpeechRecognizeFailReason

public enum SpeechRecognizeFailReason: Error, Sendable, Equatable {
    case notAuthorized
    case recognizerUnavailable
    case recognitionFailed
}


// MARK: - SpeechRecognizeUsecase

public protocol SpeechRecognizeUsecase: Sendable {

    // 세션당 최종 텍스트 1회 방출. 에러 종료 후엔 다음 startListening이 fresh 스트림으로 교체
    var result: AnyPublisher<String, any Error> { get }

    func startListening(autoStopAfterSilence: TimeInterval?)
    func stopListening()
}
