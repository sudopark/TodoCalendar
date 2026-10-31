//
//  AICommandUsecase.swift
//  AIDomainInterface
//
//  Created by sudo.park on 5/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions

public protocol AICommandUsecase: AnyObject, Sendable {
    
    func processCommand(_ commandText: String) -> AnyPublisher<AICommandProcessing, any Error>

    func processInterpretCommand(
        text: String,
        additionalInstruction: String?,
        inputSource: AICommandInputSource
    ) -> AnyPublisher<AICommandProcessing, any Error>

    func processConfirmCommand(_ action: AIConfirmCommandAction) -> AnyPublisher<AICommandProcessing, any Error>

    func rejectConfirmCommand(_ action: AIConfirmCommandAction)

    func cancelOngoingCommand(_ jobId: String)

    func clearProcessingCommandRecord() async

    func restoreCommandifNeed() -> AnyPublisher<AICommandProcessing?, any Error>

    func refreshJobStatus(_ jobId: String)
}
