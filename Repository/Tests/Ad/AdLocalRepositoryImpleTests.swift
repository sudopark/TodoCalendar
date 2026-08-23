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

    @Test("저장된 노출 이력이 없으면 빈 배열을 준다")
    func repository_whenNoStoredRecord_loadEmptyExposureRecords() {
        // given
        let repository = self.makeRepository()

        // when
        let records = repository.loadFullScreenAdExposureRecords()

        // then
        #expect(records.isEmpty == true)
    }

    @Test("노출 이력을 저장하고 다시 읽는다")
    func repository_updateAndLoadExposureRecord() {
        // given
        let repository = self.makeRepository()
        let record = FullScreenAdExposureRecord(scope: .application, lastExposeDate: self.date(100))

        // when
        repository.updateFullScreenAdExposureRecord(record)
        let records = repository.loadFullScreenAdExposureRecords()

        // then
        #expect(records == [record])
    }

    @Test("같은 scope 를 다시 기록하면 누적하지 않고 교체한다")
    func repository_updateSameScopeTwice_replaceRecord() {
        // given
        let repository = self.makeRepository()
        repository.updateFullScreenAdExposureRecord(
            .init(scope: .application, lastExposeDate: self.date(100))
        )

        // when
        let newRecord = FullScreenAdExposureRecord(scope: .application, lastExposeDate: self.date(200))
        repository.updateFullScreenAdExposureRecord(newRecord)
        let records = repository.loadFullScreenAdExposureRecords()

        // then
        #expect(records == [newRecord])
    }

    @Test("service identifier 가 다르면 각각 독립 레코드로 남는다")
    func repository_updateDifferentServiceIdentifiers_keepBothRecords() {
        // given
        let repository = self.makeRepository()

        // when
        repository.updateFullScreenAdExposureRecord(
            .init(scope: .service(identifier: "eventShare"), lastExposeDate: self.date(100))
        )
        repository.updateFullScreenAdExposureRecord(
            .init(scope: .service(identifier: "other"), lastExposeDate: self.date(200))
        )
        let records = repository.loadFullScreenAdExposureRecords()

        // then
        #expect(records.count == 2)
        #expect(records.map { $0.lastExposeDate } == [self.date(100), self.date(200)])
    }
}
