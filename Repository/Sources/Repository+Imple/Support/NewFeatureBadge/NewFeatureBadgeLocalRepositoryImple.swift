//
//  NewFeatureBadgeLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


public final class NewFeatureBadgeLocalRepositoryImple: NewFeatureBadgeRepository {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private enum Constant {
        static let key: String = "checked_new_feature_badges"
    }
}

extension NewFeatureBadgeLocalRepositoryImple {

    public func loadCheckedBadges() -> Set<NewFeatureBadge> {
        let rawValues: [String] = self.environmentStorage.load(Constant.key) ?? []
        return Set(rawValues.compactMap(NewFeatureBadge.init(rawValue:)))
    }

    public func markChecked(_ badge: NewFeatureBadge) {
        let checked = self.loadCheckedBadges().union([badge])
        self.environmentStorage.update(Constant.key, checked.map(\.rawValue).sorted())
        self.environmentStorage.synchronize()
    }
}
