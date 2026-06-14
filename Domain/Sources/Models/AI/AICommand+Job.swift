//
//  AICommand+Job.swift
//  Domain
//
//  Created by sudo.park on 5/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - process command

public struct ProcessingAICommand: Sendable {
    
    public let jobId: String
    public let isConfirmJob: Bool
    
    public init(jobId: String, isConfirmJob: Bool) {
        self.jobId = jobId
        self.isConfirmJob = isConfirmJob
    }
}


// MARK: - AIJob

public struct AIJob: Sendable {
    
    public enum Status: String, Sendable {
        case pending = "PENDING"
        case running = "RUNNING"
        case done = "DONE"
        case confirm = "CONFIRM"
        case failed = "FAILED"
        case rejected = "REJECTED"
    }
    
    public enum Mode: String, Sendable {
        case command
        case confirm
    }
    
    public let jobId: String
    // TODO: 서버 스펙에 command 추가 필요 + confirm job도 parent의 command 정보 포함되어야함
    public var command: String?
    public var status: Status?
    public var mode: Mode?
    public var result: AIJobResult?
    public var createAt: Date?
    public var updatedAt: Date?
    
    public var isFinish: Bool {
        return self.status == .done
            || self.status == .confirm
            || self.status == .failed
            || self.status == .rejected
    }
    
    public init(jobId: String) {
        self.jobId = jobId
    }
}

// MARK: - AIJobResult

public enum AIJobResult: Sendable {
    
    case done(DoneResult)
    case confirm(ConfirmResult)
    case failed(FailResult)
}

extension AIJobResult {
    
    public struct DoneResult: Sendable {
        public var text: String?
        public var mutations: [AIJobDataMutation] = []
        
        public init() { }
    }
    
    public struct ConfirmResult: Sendable {
        
        public var text: String?
        public var action: AIConfirmCommandAction?
        public var mutations: [AIJobDataMutation] = []
        
        public init() { }
    }
    
    public struct FailResult: Sendable {
        public var reason: String?
        public var mutations: [AIJobDataMutation] = []
        public var errorCode: ServerErrorModel.ErrorCode?
        
        public init() { }
    }
}

public struct AIConfirmCommandAction: Sendable {
    public var tool: String?
    public var args: Data?
    public var confirmToken: String?
    public var parentJobId: String?

    public init() { }
}

public struct AIJobDataMutation: Sendable {
    
    public enum DataType: String, Sendable {
        case todo
        case doneTodo = "done"
        case schedule
        case tag
        case eventDetail = "event_detail"
    }
    
    public enum Operation: String, Sendable {
        case created
        case updated
        case deleted
    }
    
    public let dataType: DataType
    public let operation: Operation
    
    public init(dataType: DataType, operation: Operation) {
        self.dataType = dataType
        self.operation = operation
    }
}
