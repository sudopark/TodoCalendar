//
//  SpeechRecognizeService.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - SpeechRecognizeFragment

public struct SpeechRecognizeFragment: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool

    public init(text: String, isFinal: Bool) {
        self.text = text
        self.isFinal = isFinal
    }
}


// MARK: - SpeechRecognizeService

public protocol SpeechRecognizeService: Sendable {

    var recognized: AnyPublisher<SpeechRecognizeFragment, any Error> { get }

    // raw 오디오 발화 감지 (voice activity)
    var isVoiceActive: AnyPublisher<Bool, Never> { get }

    func start() throws
    func stop()
}
