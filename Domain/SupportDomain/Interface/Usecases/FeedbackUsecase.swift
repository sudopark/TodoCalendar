//
//  FeedbackUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Extensions
import Combine

public protocol FeedbackUsecase: Sendable {
 
    func postFeedback(_ message: FeedbackPostMessage) async throws
}
