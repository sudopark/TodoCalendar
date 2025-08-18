//
//  FakeEventUploadService.swift
//  TestDoubles
//
//  Created by sudo.park on 8/10/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class FakeEventUploadService: EventUploadService {
    
    private let isUploadingFlag = EventUploadingFlag()
    
    public init() { }
    
    public func append(_ tasks: [EventUploadingTask]) async throws { }
    
    public func resume() async throws {
        self.isUploadingFlag.updateIsUploading(true)
    }
    
    public func pause() async {
        self.isUploadingFlag.updateIsUploading(false)
    }
    
    public var isUploading: EventUploadingFlag {
        return self.isUploadingFlag
    }
}
