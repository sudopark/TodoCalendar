//
//  FeedbackRepository.swift
//  Domain
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


public protocol FeedbackRepository: Sendable {
    
    func postFeedback(_ params: FeedbackMakeParams) async throws -> Void
}
