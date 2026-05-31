//
//  AICommandRepository.swift
//  Domain
//
//  Created by sudo.park on 5/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AICommandRepository: AnyObject, Sendable {
    
    func processCommand(
        _ commandText: String,
        timeZone: String
    ) async throws -> String
    
    func processConfirmCommand(
        _ action: AIConfirmCommandAction,
        timeZone: String
    ) async throws -> String
    
    func loadJob(_ jobId: String) async throws -> AIJob
    
    func updateProcessingAICommand(_ cmd: ProcessingAICommand) async throws
    func loadProcessingAICommand() async throws -> ProcessingAICommand?
    func clearProcessingAICommand() async throws
    
    func loadUsage() async throws -> AIAgentUsage
}
