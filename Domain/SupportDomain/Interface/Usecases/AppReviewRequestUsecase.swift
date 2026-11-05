//
//  AppReviewRequestUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AppReviewRequestUsecase: Sendable {

    func recordNewEventSaved()
    func canRequestReview() -> Bool
    func markReviewRequested()
}
