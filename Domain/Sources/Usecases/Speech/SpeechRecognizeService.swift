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
    
    func start() throws
    func stop()

    var recognized: AnyPublisher<SpeechRecognizeFragment, any Error> { get }

    // raw 오디오 입력 세기 (0...1 정규화 레벨)
    var voiceLevel: AnyPublisher<Float, Never> { get }
}
