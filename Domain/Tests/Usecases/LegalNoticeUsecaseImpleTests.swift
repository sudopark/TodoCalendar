//
//  LegalNoticeUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Extensions
import UnitTestHelpKit

@testable import Domain


final class LegalNoticeUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeUsecase(
        updates: LegalNoticeUpdates = [:],
        confirmedIds: [LegalDocumentType: String] = [:],
        shouldFail: Bool = false
    ) -> (LegalNoticeUsecaseImple, StubLegalNoticeRepository) {
        let stubRepository = StubLegalNoticeRepository(
            updates: updates, confirmedIds: confirmedIds, shouldFail: shouldFail
        )
        let usecase = LegalNoticeUsecaseImple(legalNoticeRepository: stubRepository)
        return (usecase, stubRepository)
    }

    private func info(_ documentType: LegalDocumentType, id: String) -> LegalNoticeUpdateInfo {
        return LegalNoticeUpdateInfo(id: id, documentType: documentType, effectiveDate: self.fixedDate)
    }
}


// MARK: - 미확인 고지 판정

extension LegalNoticeUsecaseImpleTests {

    @Test func usecase_whenUnconfirmedUpdatesExist_emitsThemSortedByDocumentType() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let privacyInfo = self.info(.privacy, id: "privacy-1")
        let expect = expectConfirm("미확인 고지 문서 순서대로 방출")
        expect.count = 2
        let (usecase, _) = self.makeUsecase(
            updates: [.privacy: privacyInfo, .terms: termsInfo]
        )

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
        }

        // then
        #expect(updates == [[], [termsInfo, privacyInfo]])
    }

    @Test func usecase_whenSomeDocumentAlreadyConfirmed_emitsOnlyUnconfirmedOnes() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let privacyInfo = self.info(.privacy, id: "privacy-1")
        let expect = expectConfirm("확인한 문서는 빠지고 나머지만 방출")
        expect.count = 2
        let (usecase, _) = self.makeUsecase(
            updates: [.terms: termsInfo, .privacy: privacyInfo],
            confirmedIds: [.terms: "terms-1"]
        )

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
        }

        // then
        #expect(updates == [[], [privacyInfo]])
    }

    @Test func usecase_whenAllDocumentsConfirmed_emitsEmpty() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let privacyInfo = self.info(.privacy, id: "privacy-1")
        let expect = expectConfirm("전부 확인했으면 빈 배열")
        expect.count = 2
        let (usecase, _) = self.makeUsecase(
            updates: [.terms: termsInfo, .privacy: privacyInfo],
            confirmedIds: [.terms: "terms-1", .privacy: "privacy-1"]
        )

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
        }

        // then
        #expect(updates == [[], []])
    }

    @Test func usecase_whenRemoteHasNoUpdates_emitsEmpty() async throws {
        // given
        let expect = expectConfirm("원격에 갱신 없으면 빈 배열")
        expect.count = 2
        let (usecase, _) = self.makeUsecase(updates: [:])

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
        }

        // then
        #expect(updates == [[], []])
    }

    @Test func usecase_whenLoadFails_emitsEmpty() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let expect = expectConfirm("조회 실패해도 빈 배열")
        expect.count = 2
        let (usecase, _) = self.makeUsecase(updates: [.terms: termsInfo], shouldFail: true)

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
        }

        // then
        #expect(updates == [[], []])
    }
}


// MARK: - 고지 확인 처리

extension LegalNoticeUsecaseImpleTests {

    @Test func usecase_confirmNotice_persistsIdForThatDocumentTypeOnly() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let privacyInfo = self.info(.privacy, id: "privacy-1")
        let expect = expectConfirm("confirm 은 해당 문서 id 만 저장")
        expect.count = 3
        let (usecase, stubRepository) = self.makeUsecase(
            updates: [.terms: termsInfo, .privacy: privacyInfo]
        )

        // when
        _ = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
            try await Task.sleep(for: .milliseconds(50))
            usecase.confirmNotice(.terms)
        }

        // then
        #expect(stubRepository.didUpdateConfirmedId?.id == "terms-1")
        #expect(stubRepository.didUpdateConfirmedId?.documentType == .terms)
        #expect(stubRepository.fetchConfirmedNoticeId(.privacy) == nil)
    }

    @Test func usecase_confirmNotice_removesOnlyThatDocumentFromPending() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let privacyInfo = self.info(.privacy, id: "privacy-1")
        let expect = expectConfirm("confirm 한 문서만 pending 에서 빠진다")
        expect.count = 3
        let (usecase, _) = self.makeUsecase(
            updates: [.terms: termsInfo, .privacy: privacyInfo]
        )

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
            try await Task.sleep(for: .milliseconds(50))
            usecase.confirmNotice(.terms)
        }

        // then
        #expect(updates == [[], [termsInfo, privacyInfo], [privacyInfo]])
    }

    @Test func usecase_confirmNotice_whenDocumentNotPending_doesNothing() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let expect = expectConfirm("pending 에 없는 문서는 confirm 해도 무시")
        expect.count = 2
        let (usecase, stubRepository) = self.makeUsecase(
            updates: [.terms: termsInfo]
        )

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
            try await Task.sleep(for: .milliseconds(50))
            usecase.confirmNotice(.privacy)
        }

        // then
        #expect(updates == [[], [termsInfo]])
        #expect(stubRepository.didUpdateConfirmedId == nil)
    }

    @Test func usecase_afterConfirm_recheckKeepsItConfirmed() async throws {
        // given
        let termsInfo = self.info(.terms, id: "terms-1")
        let privacyInfo = self.info(.privacy, id: "privacy-1")
        let expect = expectConfirm("confirm 후 재체크해도 확인한 문서는 안 돌아온다")
        expect.count = 4
        let (usecase, _) = self.makeUsecase(
            updates: [.terms: termsInfo, .privacy: privacyInfo]
        )

        // when
        let updates = try await self.outputs(expect, for: usecase.pendingNoticeUpdates) {
            usecase.checkNoticeIsNeed()
            try await Task.sleep(for: .milliseconds(50))
            usecase.confirmNotice(.terms)
            try await Task.sleep(for: .milliseconds(50))
            usecase.checkNoticeIsNeed()
        }

        // then
        #expect(updates == [[], [termsInfo, privacyInfo], [privacyInfo], [privacyInfo]])
    }
}


// MARK: - Stub

private final class StubLegalNoticeRepository: LegalNoticeRepository, @unchecked Sendable {

    private let updates: LegalNoticeUpdates
    private let shouldFail: Bool
    private var confirmedIds: [LegalDocumentType: String]
    private(set) var didUpdateConfirmedId: (id: String, documentType: LegalDocumentType)?

    init(
        updates: LegalNoticeUpdates = [:],
        confirmedIds: [LegalDocumentType: String] = [:],
        shouldFail: Bool = false
    ) {
        self.updates = updates
        self.confirmedIds = confirmedIds
        self.shouldFail = shouldFail
    }

    func loadNoticeUpdates() async throws -> LegalNoticeUpdates {
        if self.shouldFail { throw RuntimeError("load notice updates failed") }
        return self.updates
    }

    func fetchConfirmedNoticeId(_ documentType: LegalDocumentType) -> String? {
        return self.confirmedIds[documentType]
    }

    func updateConfirmedNoticeId(_ id: String, for documentType: LegalDocumentType) {
        self.confirmedIds[documentType] = id
        self.didUpdateConfirmedId = (id, documentType)
    }
}
