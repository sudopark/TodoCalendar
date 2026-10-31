//
//  DDayCandidateUsecase.swift
//  EventDomainInterface
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine

public protocol DDayCandidateUsecase: Sendable {

    func refresh()
    func append(_ candidate: DDayCandidate)
    func remove(_ candidate: DDayCandidate)

    var candidates: AnyPublisher<[DDayCandidate], Never> { get }
}
