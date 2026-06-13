//
//  StubAICommandRepository.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine
import Extensions

@testable import Domain


class BaseStubAICommandRepository: AICommandRepository, @unchecked Sendable {
    
    var shouldFailProcessCommand: Bool = false
    func processCommand(_ commandText: String, timeZone: String) async throws -> String {
        guard !self.shouldFailProcessCommand
        else {
            throw RuntimeError("not imple")
        }
        return "some_job"
    }

    var shouldFailProcessConfirmCommand: Bool = false
    func processConfirmCommand(_ action: AIConfirmCommandAction, timeZone: String) async throws -> String {
        guard !self.shouldFailProcessConfirmCommand
        else {
            throw RuntimeError("not imple")
        }
        return "some_job"
    }

    var didRejectConfirmActionToken: String?
    func rejectConfirmCommand(_ action: AIConfirmCommandAction) async throws {
        self.didRejectConfirmActionToken = action.confirmToken
    }


    var stubLoadJobs: [Result<AIJob, any Error>] = []
    var loadJobMocking: Result<AIJob, any Error>?
    func loadJob(_ jobId: String) async throws -> AIJob {
        
        if let mocking = self.loadJobMocking {
            switch mocking {
            case .success(let job): return job
            case .failure(let error): throw error
            }
        }
        
        if self.stubLoadJobs.isEmpty {
            throw RuntimeError("failed")
        }
        
        let first = self.stubLoadJobs.removeFirst()
        switch first {
        case .success(let job): return job
        case .failure(let error): throw error
        }
    }
    
    private var processingCmd: ProcessingAICommand?
    func updateProcessingAICommand(_ cmd: ProcessingAICommand) async throws {
        self.processingCmd = cmd
    }
    
    func loadProcessingAICommand() async throws -> ProcessingAICommand? {
        return self.processingCmd
    }
    
    func clearProcessingAICommand() async throws {
        self.processingCmd = nil
    }
    
    func loadUsage() async throws -> AIAgentUsage {
        throw RuntimeError("not imple")
    }
}
