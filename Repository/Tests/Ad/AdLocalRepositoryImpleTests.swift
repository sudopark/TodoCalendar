//
//  AdLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import Repository


struct AdLocalRepositoryImpleTests {

    private func makeRepository() -> AdLocalRepositoryImple {
        return AdLocalRepositoryImple(environmentStorage: FakeEnvironmentStorage())
    }

    private func date(_ timeStamp: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: timeStamp)
    }
}

extension AdLocalRepositoryImpleTests {

    @Test("저장된 노출 이력이 없으면 nil 을 준다")
    func repository_whenNoStoredRecord_loadNil() {
        // given
        let repository = self.makeRepository()

        // when
        let record = repository.loadFullScreenAdExposureRecord()

        // then
        #expect(record == nil)
    }

    @Test("노출 이력을 저장하고 다시 읽는다")
    func repository_updateAndLoadExposureRecord() {
        // given
        let repository = self.makeRepository()
        let record = FullScreenAdExposureRecord(lastExposeDate: self.date(100), countOfDay: 2)

        // when
        repository.updateFullScreenAdExposureRecord(record)
        let loaded = repository.loadFullScreenAdExposureRecord()

        // then
        #expect(loaded == record)
    }

    @Test("노출 이력을 다시 저장하면 교체한다")
    func repository_updateTwice_replaceRecord() {
        // given
        let repository = self.makeRepository()
        repository.updateFullScreenAdExposureRecord(
            .init(lastExposeDate: self.date(100), countOfDay: 1)
        )

        // when
        let newRecord = FullScreenAdExposureRecord(lastExposeDate: self.date(200), countOfDay: 2)
        repository.updateFullScreenAdExposureRecord(newRecord)
        let loaded = repository.loadFullScreenAdExposureRecord()

        // then
        #expect(loaded == newRecord)
    }
}


// MARK: - 추적 안내 노출 기록

extension AdLocalRepositoryImpleTests {

    @Test("기록이 없으면 추적 안내를 보여준 적 없다고 답한다")
    func repository_loadHasShownTrackingGuide_whenEmpty_isFalse() {
        // given
        let repository = self.makeRepository()

        // when
        let hasShown = repository.loadHasShownTrackingGuide()

        // then
        #expect(hasShown == false)
    }

    @Test("기록한 뒤에는 추적 안내를 보여준 적 있다고 답한다")
    func repository_markTrackingGuideShown_thenLoadIsTrue() {
        // given
        let repository = self.makeRepository()

        // when
        repository.markTrackingGuideShown()
        let hasShown = repository.loadHasShownTrackingGuide()

        // then
        #expect(hasShown == true)
    }

    @Test("추적 안내 기록이 전면 광고 노출 이력을 덮지 않는다")
    func repository_markTrackingGuideShown_keepsExposureRecords() {
        // given
        let repository = self.makeRepository()
        let record = FullScreenAdExposureRecord(lastExposeDate: self.date(100), countOfDay: 1)
        repository.updateFullScreenAdExposureRecord(record)

        // when
        repository.markTrackingGuideShown()

        // then
        #expect(repository.loadFullScreenAdExposureRecord() == record)
        #expect(repository.loadHasShownTrackingGuide() == true)
    }
}
