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

    // 시스템이 오디오 입력을 회수한 순간 (인터럽션 · 입력 라우트 소실).
    // 앱은 여전히 활성이라 앱 생명주기 이벤트로는 감지되지 않는다.
    var audioInputDisrupted: AnyPublisher<Void, Never> { get }
}
