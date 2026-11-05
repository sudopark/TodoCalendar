//
//  AppUsageRecordLocalRepositoryImpleTests.swift
//  SupportDomainTests
//
//  Created by sudo.park on 11/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import StorageInfraTesting
@testable import SupportDomain
@testable import SupportDomainInterface


struct AppUsageRecordLocalRepositoryImpleTests {

    private let storage = FakeEnvironmentStorage()

    private func makeRepository() -> AppUsageRecordLocalRepositoryImple {
        return AppUsageRecordLocalRepositoryImple(environmentStorage: self.storage)
    }
}


extension AppUsageRecordLocalRepositoryImpleTests {

    @Test("저장된 기록이 없으면 새 이벤트 저장 수는 0, 리뷰 요청 버전은 nil 이다")
    func repository_whenNothingSaved_countIsZeroAndVersionIsNil() {
        // given
        let repository = self.makeRepository()

        // when
        let count = repository.loadSavedNewEventCount()
        let version = repository.loadLastReviewRequestedAppVersion()

        // then
        #expect(count == 0)
        #expect(version == nil)
    }

    @Test("새 이벤트 저장 수는 늘린 만큼 누적되고 저장소를 다시 열어도 읽힌다")
    func repository_increaseSavedNewEventCount_accumulates() {
        // given
        let repository = self.makeRepository()

        // when
        repository.increaseSavedNewEventCount()
        repository.increaseSavedNewEventCount()
        repository.increaseSavedNewEventCount()
        let count = self.makeRepository().loadSavedNewEventCount()

        // then
        #expect(count == 3)
    }

    @Test("리뷰를 요청한 앱 버전은 저장소를 다시 열어도 읽힌다")
    func repository_saveLastReviewRequestedAppVersion_loadsSavedVersion() {
        // given
        let repository = self.makeRepository()

        // when
        repository.saveLastReviewRequestedAppVersion("3.1.2")
        let version = self.makeRepository().loadLastReviewRequestedAppVersion()

        // then
        #expect(version == "3.1.2")
    }
}
