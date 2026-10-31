//
//  ProcessingAICommandTable.swift
//  AIDomain
//
//  Created by sudo.park on 6/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import AIDomainInterface


public typealias ProcessingAICommandTable = ProcessingAICommandTableV0

@Table("ProcessingAICommand")
public struct ProcessingAICommandTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "job_id")
    public let jobId: String
    
    @Column(.notNull, name: "is_confirm_job")
    public let isConfirmJob: Bool
}


extension ProcessingAICommandTable.Entity {

    public init(_ command: ProcessingAICommand) {
        self.init(
            jobId: command.jobId,
            isConfirmJob: command.isConfirmJob
        )
    }

    func asProcessingAICommand() -> ProcessingAICommand {
        return ProcessingAICommand(
            jobId: self.jobId,
            isConfirmJob: self.isConfirmJob
        )
    }
}
