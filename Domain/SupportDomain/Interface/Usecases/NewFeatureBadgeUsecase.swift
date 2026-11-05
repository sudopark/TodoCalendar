//
//  NewFeatureBadgeUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


public protocol NewFeatureBadgeUsecase: Sendable {

    func prepare()
    func markChecked(_ badge: NewFeatureBadge)

    var uncheckedBadges: AnyPublisher<Set<NewFeatureBadge>, Never> { get }
}
