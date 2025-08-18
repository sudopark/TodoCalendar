//
//  StubEventUploadService.swift
//  TestDoubles
//
//  Created by sudo.park on 8/11/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain

open class StubEventUploadService: EventUploadService, @unchecked Sendable {
    
    private let isUpoadingFlag = EventUploadingFlag()
    public init() { }
    
    open func append(_ tasks: [EventUploadingTask]) async throws { }
    
    
    public var isResumeOrPauses: [Bool] = []
    
    open func resume() async throws {
        self.isUpoadingFlag.updateIsUploading(true)
        self.isResumeOrPauses.append(true)
    }
    
    open func pause() async {
        self.isUpoadingFlag.updateIsUploading(false)
        self.isResumeOrPauses.append(false)
    }
    
    public var isUploading: EventUploadingFlag { self.isUpoadingFlag }
}
