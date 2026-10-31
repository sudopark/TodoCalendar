//
//  NewFeatureBadgeRepository.swift
//  Domain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol NewFeatureBadgeRepository: Sendable {

    func loadCheckedBadges() -> Set<NewFeatureBadge>
    func markChecked(_ badge: NewFeatureBadge)
}
