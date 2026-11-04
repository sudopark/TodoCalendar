//
//  NewFeatureBadgeLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import Repository


struct NewFeatureBadgeLocalRepositoryImpleTests {

    private let storage = FakeEnvironmentStorage()

    private func makeRepository() -> NewFeatureBadgeLocalRepositoryImple {
        return NewFeatureBadgeLocalRepositoryImple(environmentStorage: self.storage)
    }
}


// MARK: - 확인 기록

extension NewFeatureBadgeLocalRepositoryImpleTests {

    @Test("확인 기록이 없으면 빈 집합을 읽는다")
    func loadCheckedBadges_whenNothingChecked_isEmpty() {
        // given
        let repository = self.makeRepository()

        // when
        let checked = repository.loadCheckedBadges()

        // then
        #expect(checked.isEmpty)
    }

    @Test("확인한 뱃지는 저장소를 다시 열어도 읽힌다")
    func markChecked_persistsBadge() {
        // given
        let repository = self.makeRepository()

        // when
        repository.markChecked(.widgetSetting)
        let checked = self.makeRepository().loadCheckedBadges()

        // then
        #expect(checked == [.widgetSetting])
    }
}
