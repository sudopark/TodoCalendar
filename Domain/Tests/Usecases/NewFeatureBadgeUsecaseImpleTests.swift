//
//  NewFeatureBadgeUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Foundation
import UnitTestHelpKit

@testable import Domain


final class NewFeatureBadgeUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private final class StubRepository: NewFeatureBadgeRepository, @unchecked Sendable {

        private var checked: Set<NewFeatureBadge>
        var didMarkCheckedWith: NewFeatureBadge?

        init(checked: Set<NewFeatureBadge>) {
            self.checked = checked
        }

        func loadCheckedBadges() -> Set<NewFeatureBadge> {
            return self.checked
        }

        func markChecked(_ badge: NewFeatureBadge) {
            self.didMarkCheckedWith = badge
            self.checked.insert(badge)
        }
    }

    private func makeUsecase(
        checked: Set<NewFeatureBadge> = [],
        repository: StubRepository? = nil
    ) -> NewFeatureBadgeUsecaseImple {
        return NewFeatureBadgeUsecaseImple(
            repository: repository ?? StubRepository(checked: checked),
            sharedDataStore: SharedDataStore(serialEventQeueu: nil)
        )
    }
}


// MARK: - 확인 안 한 뱃지

extension NewFeatureBadgeUsecaseImpleTests {

    @Test("prepare 전에는 뱃지를 내지 않는다")
    func uncheckedBadges_beforePrepare_isEmpty() async throws {
        // given
        let expect = expectConfirm("빈 집합 방출")
        let usecase = self.makeUsecase(checked: [])

        // when
        let badges = try await self.firstOutput(expect, for: usecase.uncheckedBadges)

        // then
        #expect(badges == [])
    }

    @Test("prepare 하면 확인 기록이 없는 뱃지를 낸다")
    func prepare_whenNotChecked_emitsAllBadges() async throws {
        // given
        let expect = expectConfirm("빈 집합 -> 전체 뱃지")
        expect.count = 2
        let usecase = self.makeUsecase(checked: [])

        // when
        let badges = try await self.outputs(expect, for: usecase.uncheckedBadges) {
            usecase.prepare()
        }

        // then
        #expect(badges == [[], [.widgetSetting]])
    }

    @Test("이미 확인한 뱃지는 prepare 해도 내지 않는다")
    func prepare_whenAlreadyChecked_excludesCheckedBadge() async throws {
        // given
        let expect = expectConfirm("확인분을 뺀 빈 집합")
        let usecase = self.makeUsecase(checked: [.widgetSetting])

        // when
        usecase.prepare()
        let badges = try await self.firstOutput(expect, for: usecase.uncheckedBadges)

        // then
        #expect(badges == [])
    }
}


// MARK: - 확인 처리

extension NewFeatureBadgeUsecaseImpleTests {

    @Test("확인하면 그 뱃지가 사라진다")
    func markChecked_removesBadgeFromUnchecked() async throws {
        // given
        let expect = expectConfirm("빈 집합 -> 전체 -> 빈 집합")
        expect.count = 3
        let usecase = self.makeUsecase(checked: [])

        // when
        let badges = try await self.outputs(expect, for: usecase.uncheckedBadges) {
            usecase.prepare()
            usecase.markChecked(.widgetSetting)
        }

        // then
        #expect(badges == [[], [.widgetSetting], []])
    }

    @Test("확인하면 저장소에 그 뱃지를 기록한다")
    func markChecked_persistsBadgeToRepository() async throws {
        // given
        let repository = StubRepository(checked: [])
        let usecase = self.makeUsecase(repository: repository)

        // when
        usecase.markChecked(.widgetSetting)

        // then
        #expect(repository.didMarkCheckedWith == .widgetSetting)
    }

    @Test("prepare 전에 확인해도 이후 prepare 가 그 뱃지를 내지 않는다")
    func markChecked_beforePrepare_keepsBadgeHiddenAfterPrepare() async throws {
        // given
        let expect = expectConfirm("확인분이 반영된 빈 집합")
        let usecase = self.makeUsecase(checked: [])

        // when
        usecase.markChecked(.widgetSetting)
        usecase.prepare()
        let badges = try await self.firstOutput(expect, for: usecase.uncheckedBadges)

        // then
        #expect(badges == [])
    }
}
