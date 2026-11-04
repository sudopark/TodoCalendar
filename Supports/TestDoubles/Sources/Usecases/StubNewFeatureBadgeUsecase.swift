//
//  StubNewFeatureBadgeUsecase.swift
//  TestDoubles
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


public final class StubNewFeatureBadgeUsecase: NewFeatureBadgeUsecase, @unchecked Sendable {

    private let uncheckedBadgesSubject: CurrentValueSubject<Set<NewFeatureBadge>, Never>

    public init(uncheckedBadges: Set<NewFeatureBadge> = []) {
        self.uncheckedBadgesSubject = .init(uncheckedBadges)
    }

    public var didPrepare: Bool?

    public func prepare() {
        self.didPrepare = true
    }

    public var didMarkCheckedWith: NewFeatureBadge?

    public func markChecked(_ badge: NewFeatureBadge) {
        self.didMarkCheckedWith = badge
        self.uncheckedBadgesSubject.send(self.uncheckedBadgesSubject.value.subtracting([badge]))
    }

    public var uncheckedBadges: AnyPublisher<Set<NewFeatureBadge>, Never> {
        return self.uncheckedBadgesSubject.eraseToAnyPublisher()
    }
}
