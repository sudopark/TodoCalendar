//
//  LegalNoticeRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Extensions

@testable import Repository

struct LegalNoticeRepositoryImpleTests {

    private func makeRepository(
        responseJson: String = "{}",
        shouldFail: Bool = false
    ) -> LegalNoticeRepositoryImple {
        let stub = StubRemoteAPI(responses: [
            .init(endpoint: AppEndpoints.legalNotice, resultJsonString: .success(responseJson))
        ])
        stub.shouldFailRequest = shouldFail
        return LegalNoticeRepositoryImple(
            remoteAPI: stub, environmentStorage: FakeEnvironmentStorage()
        )
    }

    private var utcDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}

// MARK: - loadNoticeUpdates 매핑

extension LegalNoticeRepositoryImpleTests {

    @Test func repository_whenNoUpdates_returnsEmptyUpdates() async throws {
        // given
        let repository = self.makeRepository(responseJson: "{}")

        // when
        let updates = try await repository.loadNoticeUpdates()

        // then
        #expect(updates.isEmpty)
    }

    @Test func repository_loadNoticeUpdates_mapsBothDocuments() async throws {
        // given
        let json = """
        {
          "terms": { "id": "2026-09-01-terms", "effective_date": "2026-09-01" },
          "privacy": { "id": "2026-09-15-privacy", "effective_date": "2026-09-15" }
        }
        """
        let repository = self.makeRepository(responseJson: json)

        // when
        let updates = try await repository.loadNoticeUpdates()

        // then
        #expect(updates[.terms]?.id == "2026-09-01-terms")
        #expect(updates[.terms]?.documentType == .terms)
        #expect(updates[.terms]?.effectiveDate == self.utcDateFormatter.date(from: "2026-09-01"))
        #expect(updates[.privacy]?.id == "2026-09-15-privacy")
        #expect(updates[.privacy]?.effectiveDate == self.utcDateFormatter.date(from: "2026-09-15"))
    }

    @Test func repository_whenTopLevelKeyUnknown_returnsEmptyUpdates() async throws {
        // given
        let json = """
        { "unknown": { "id": "some-id", "effective_date": "2026-09-01" } }
        """
        let repository = self.makeRepository(responseJson: json)

        // when
        let updates = try await repository.loadNoticeUpdates()

        // then
        #expect(updates.isEmpty)
    }

    @Test func repository_whenSomeTopLevelKeysUnknown_keepsKnownOnes() async throws {
        // given
        let json = """
        {
          "terms": { "id": "2026-09-01-terms", "effective_date": "2026-09-01" },
          "unknown": { "id": "some-id", "effective_date": "2026-09-01" }
        }
        """
        let repository = self.makeRepository(responseJson: json)

        // when
        let updates = try await repository.loadNoticeUpdates()

        // then
        #expect(Set(updates.keys) == Set([.terms]))
    }

    @Test func repository_whenOneItemMissingId_dropsOnlyThatItem() async throws {
        // given
        let json = """
        {
          "terms": { "effective_date": "2026-09-01" },
          "privacy": { "id": "2026-09-15-privacy", "effective_date": "2026-09-15" }
        }
        """
        let repository = self.makeRepository(responseJson: json)

        // when
        let updates = try await repository.loadNoticeUpdates()

        // then
        #expect(updates[.terms] == nil)
        #expect(updates[.privacy]?.id == "2026-09-15-privacy")
    }

    @Test func repository_whenOneItemEffectiveDateMalformed_dropsOnlyThatItem() async throws {
        // given
        let json = """
        {
          "terms": { "id": "2026-09-01-terms", "effective_date": "September 1" },
          "privacy": { "id": "2026-09-15-privacy", "effective_date": "2026-09-15" }
        }
        """
        let repository = self.makeRepository(responseJson: json)

        // when
        let updates = try await repository.loadNoticeUpdates()

        // then
        #expect(updates[.terms] == nil)
        #expect(updates[.privacy]?.id == "2026-09-15-privacy")
    }

    @Test func repository_whenLoadFails_throws() async throws {
        // given
        let repository = self.makeRepository(shouldFail: true)

        // when, then
        await #expect(throws: (any Error).self) {
            try await repository.loadNoticeUpdates()
        }
    }
}

// MARK: - 확인 이력 저장 (문서별)

extension LegalNoticeRepositoryImpleTests {

    @Test func repository_confirmedNoticeId_roundTrips() async throws {
        // given
        let repository = self.makeRepository()

        // when
        repository.updateConfirmedNoticeId("2026-09-01-terms", for: .terms)
        let confirmed = repository.fetchConfirmedNoticeId(.terms)

        // then
        #expect(confirmed == "2026-09-01-terms")
    }

    @Test func repository_fetchConfirmedNoticeId_whenNeverConfirmed_returnsNil() async throws {
        // given
        let repository = self.makeRepository()

        // when
        let confirmed = repository.fetchConfirmedNoticeId(.terms)

        // then
        #expect(confirmed == nil)
    }

    @Test func repository_confirmedNoticeId_isIndependentPerDocumentType() async throws {
        // given
        let repository = self.makeRepository()

        // when
        repository.updateConfirmedNoticeId("2026-09-01-terms", for: .terms)

        // then
        #expect(repository.fetchConfirmedNoticeId(.terms) == "2026-09-01-terms")
        #expect(repository.fetchConfirmedNoticeId(.privacy) == nil)
    }
}
