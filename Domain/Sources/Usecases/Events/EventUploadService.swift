//
//  EventUploadService.swift
//  Domain
//
//  Created by sudo.park on 7/23/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public struct EventUploadingFlag: @unchecked Sendable {
    
    public init() { }
    
    private let subject = CurrentValueSubject<Bool, Never>(false)
    
    public func updateIsUploading(_ isUploading: Bool) {
        self.subject.send(isUploading)
    }
    
    public var isUploading: AnyPublisher<Bool, Never> {
        return self.subject.eraseToAnyPublisher()
    }
    
    public var value: Bool {
        return self.subject.value
    }
}

public protocol EventUploadService: Sendable {
    
    func append(_ task: EventUploadingTask) async throws
    func resume() async throws
    func pause() async
    func rescheduleUploadFailedJobs() async throws
    
    var isUploading: EventUploadingFlag { get async }
}

extension EventUploadService {
    
    public func waitUntilUploadingEnd(
        _ checkInterval: Duration = .milliseconds(10)
    ) async throws {
        
        while await self.isUploading.value {
            try await Task.sleep(for: checkInterval)
        }
    }
}
