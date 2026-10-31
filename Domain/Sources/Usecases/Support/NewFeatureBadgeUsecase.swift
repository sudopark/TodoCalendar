//
//  NewFeatureBadgeUsecase.swift
//  Domain
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


public final class NewFeatureBadgeUsecaseImple: NewFeatureBadgeUsecase, @unchecked Sendable {

    private let repository: any NewFeatureBadgeRepository
    private let sharedDataStore: SharedDataStore

    public init(
        repository: any NewFeatureBadgeRepository,
        sharedDataStore: SharedDataStore
    ) {
        self.repository = repository
        self.sharedDataStore = sharedDataStore
    }

    private var shareKey: String { ShareDataKeys.checkedNewFeatureBadges.rawValue }
}


// MARK: - command

extension NewFeatureBadgeUsecaseImple {

    public func prepare() {
        self.sharedDataStore.put(
            Set<NewFeatureBadge>.self, key: self.shareKey, self.repository.loadCheckedBadges()
        )
    }

    public func markChecked(_ badge: NewFeatureBadge) {
        self.repository.markChecked(badge)
        self.sharedDataStore.put(
            Set<NewFeatureBadge>.self, key: self.shareKey, self.repository.loadCheckedBadges()
        )
    }
}


// MARK: - query

extension NewFeatureBadgeUsecaseImple {

    /// `prepare()` 전에는 확인 여부를 모르므로 아무 뱃지도 내지 않는다 — 확인한 유저에게 뱃지가 깜빡이지 않는다.
    public var uncheckedBadges: AnyPublisher<Set<NewFeatureBadge>, Never> {
        return self.sharedDataStore
            .observe(Set<NewFeatureBadge>.self, key: self.shareKey)
            .map { checked in
                guard let checked else { return [] }
                return Set(NewFeatureBadge.allCases).subtracting(checked)
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
