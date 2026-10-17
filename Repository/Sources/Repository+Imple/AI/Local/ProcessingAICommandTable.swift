//
//  ProcessingAICommandTable.swift
//  Repository
//
//  Created by sudo.park on 6/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import Domain


typealias ProcessingAICommandTable = ProcessingAICommandTableV0

@Table("ProcessingAICommand")
struct ProcessingAICommandTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "job_id")
    let jobId: String
    
    @Column(.notNull, name: "is_confirm_job")
    let isConfirmJob: Bool
}


extension ProcessingAICommandTable.Entity {

    init(_ command: ProcessingAICommand) {
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
