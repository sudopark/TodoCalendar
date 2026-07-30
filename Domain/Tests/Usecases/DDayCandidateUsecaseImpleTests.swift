//
//  DDayCandidateUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Foundation
import UnitTestHelpKit

@testable import Domain


final class DDayCandidateUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private final class StubRepository: DDayCandidateRepository, @unchecked Sendable {

        private var candidates: [DDayCandidate]
        init(_ candidates: [DDayCandidate] = []) {
            self.candidates = candidates
        }

        func loadCandidates() -> [DDayCandidate] {
            return self.candidates
        }

        func append(_ candidate: DDayCandidate) -> [DDayCandidate] {
            guard !self.candidates.contains(candidate) else { return self.candidates }
            self.candidates = self.candidates + [candidate]
            return self.candidates
        }

        func remove(_ candidate: DDayCandidate) -> [DDayCandidate] {
            self.candidates = self.candidates.filter { $0 != candidate }
            return self.candidates
        }
    }

    /// `candidates`는 구독 즉시 refresh 전 공유 상태(`[]`)를 한 번 방출한다.
    /// 그래서 기대 방출 수는 "빈 첫 방출 + 실제 변화 수"다.
    private func makeUsecase(
        stubCandidates: [DDayCandidate] = []
    ) -> DDayCandidateUsecaseImple {
        return DDayCandidateUsecaseImple(
            repository: StubRepository(stubCandidates),
            sharedDataStore: .init()
        )
    }
}


// MARK: - 목록 조회

extension DDayCandidateUsecaseImpleTests {

    @Test("refresh하면 저장된 후보를 방출한다")
    func refresh_emitsStoredCandidates() async throws {
        // given
        let expect = expectConfirm("저장된 후보 방출")
        expect.count = 2
        let usecase = self.makeUsecase(
            stubCandidates: [.init(scheduleId: "s1"), .init(scheduleId: "s2", turnKey: "300")]
        )

        // when
        let outputs = try await self.outputs(expect, for: usecase.candidates) {
            usecase.refresh()
        }

        // then
        #expect(outputs.last == [.init(scheduleId: "s1"), .init(scheduleId: "s2", turnKey: "300")])
    }
}


// MARK: - 등록

extension DDayCandidateUsecaseImpleTests {

    @Test("등록하면 목록에 추가된다")
    func append_addsCandidate() async throws {
        // given
        let expect = expectConfirm("등록 후 목록 방출")
        expect.count = 3
        let usecase = self.makeUsecase()

        // when
        let outputs = try await self.outputs(expect, for: usecase.candidates) {
            usecase.refresh()
            usecase.append(.init(scheduleId: "s1", turnKey: "300"))
        }

        // then
        #expect(outputs.last == [.init(scheduleId: "s1", turnKey: "300")])
    }

    @Test("같은 회차를 다시 등록해도 중복되지 않는다")
    func append_whenAlreadyRegistered_doesNotDuplicate() async throws {
        // given
        let expect = expectConfirm("중복 등록 방지")
        expect.count = 3
        let usecase = self.makeUsecase(stubCandidates: [.init(scheduleId: "s1", turnKey: "300")])

        // when
        let outputs = try await self.outputs(expect, for: usecase.candidates) {
            usecase.refresh()
            usecase.append(.init(scheduleId: "s1", turnKey: "300"))
        }

        // then
        #expect(outputs.last == [.init(scheduleId: "s1", turnKey: "300")])
    }

    @Test("같은 일정의 다른 회차는 별개로 등록된다")
    func append_whenSameScheduleDifferentTurn_addsBoth() async throws {
        // given
        let expect = expectConfirm("회차별 등록")
        expect.count = 3
        let usecase = self.makeUsecase(stubCandidates: [.init(scheduleId: "s1", turnKey: "300")])

        // when
        let outputs = try await self.outputs(expect, for: usecase.candidates) {
            usecase.refresh()
            usecase.append(.init(scheduleId: "s1", turnKey: "900"))
        }

        // then
        #expect(outputs.last?.count == 2)
    }
}


// MARK: - 해제

extension DDayCandidateUsecaseImpleTests {

    @Test("해제하면 목록에서 빠진다")
    func remove_dropsCandidate() async throws {
        // given
        let expect = expectConfirm("해제 후 목록 방출")
        expect.count = 3
        let usecase = self.makeUsecase(
            stubCandidates: [.init(scheduleId: "s1"), .init(scheduleId: "s2")]
        )

        // when
        let outputs = try await self.outputs(expect, for: usecase.candidates) {
            usecase.refresh()
            usecase.remove(.init(scheduleId: "s1"))
        }

        // then
        #expect(outputs.last == [.init(scheduleId: "s2")])
    }
}
