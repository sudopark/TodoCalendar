//
//  SpyEventUploadService.swift
//  EventDomainTests
//
//  Created by sudo.park on 8/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
@testable import EventDomain
@testable import EventDomainInterface


final class SpyEventUploadService: EventUploadService, @unchecked Sendable {
    
    var uploadTasks: [EventUploadingTask] = []
    
    func append(_ tasks: [EventUploadingTask]) async throws {
        let newTaskIdSet = Set(tasks.map { $0.uuid })
        self.uploadTasks = self.uploadTasks.filter { !newTaskIdSet.contains($0.uuid) }
        self.uploadTasks.append(contentsOf: tasks)
    }
    
    func resume() async throws { }
    
    func pause() async { }
    
    var isUploading: EventUploadingFlag { .init() }
}
