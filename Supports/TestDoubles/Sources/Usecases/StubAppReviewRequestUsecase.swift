//
//  StubAppReviewRequestUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class StubAppReviewRequestUsecase: AppReviewRequestUsecase, @unchecked Sendable {

    private let canRequest: Bool

    public init(canRequest: Bool = false) {
        self.canRequest = canRequest
    }

    public var recordedNewEventSavedCount: Int = 0

    public func recordNewEventSaved() {
        self.recordedNewEventSavedCount += 1
    }

    public func canRequestReview() -> Bool {
        return self.canRequest
    }

    public var didMarkReviewRequested: Bool?

    public func markReviewRequested() {
        self.didMarkReviewRequested = true
    }
}
