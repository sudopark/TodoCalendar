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
        case canceled = "CANCELED"
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
            || self.status == .canceled
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
    case canceled(CanceledResult)
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

    public struct CanceledResult: Sendable {
        public var mutations: [AIJobDataMutation] = []

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


// MARK: - mutation event-sync 판정

extension AIJobResult {

    public var mutations: [AIJobDataMutation] {
        switch self {
        case .done(let result): return result.mutations
        case .confirm(let result): return result.mutations
        case .failed(let result): return result.mutations
        case .canceled(let result): return result.mutations
        }
    }
}

extension AIJobDataMutation.DataType {

    // 델타 event sync(eventTag/todo/schedule)로 커버되는 dataType.
    // done은 동반 todo mutation으로 반영, event_detail은 상세화면 on-demand 로드라 제외.
    public var requiresEventSync: Bool {
        switch self {
        case .todo, .schedule, .tag: return true
        case .doneTodo, .eventDetail: return false
        }
    }
}
