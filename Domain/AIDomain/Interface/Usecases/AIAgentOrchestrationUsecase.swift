//
//  AIAgentOrchestrationUsecase.swift
//  AIDomainInterface
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - AIAgentOrchestrationUsecase

public protocol AIAgentOrchestrationUsecase: AnyObject, Sendable {

    var state: AnyPublisher<AIAgentState, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }
    var recognizingText: AnyPublisher<String, Never> { get }
    var voiceLevel: AnyPublisher<Float, Never> { get }
    var speechPermissionDenied: AnyPublisher<Void, Never> { get }
    var isNotificationPermissionDenied: AnyPublisher<Bool, Never> { get }
    var isCreditExhausted: Bool { get }

    func prepare()
    func enterVoiceInput()
    func finishVoiceInput()
    func enterKeyboardInput()
    func enterImageInput()
    func stopInput()
    func submit(_ text: String) throws
    func submitImageCommand(text: String, additionalInstruction: String?) throws

    func confirm()
    func decline()

    func reset()
    func restoreIfNeeded()
    func loadUsage()

    func handleJobStatusChanged(_ jobId: String)
    func refreshProcessingJobIfNeeded()

    func refreshNotificationPermissionStatus()
}
