//
//  DDayCandidateLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import Repository


struct DDayCandidateLocalRepositoryImpleTests {

    private func makeRepository(
        storage: FakeEnvironmentStorage = .init()
    ) -> DDayCandidateLocalRepositoryImple {
        return DDayCandidateLocalRepositoryImple(environmentStorage: storage)
    }

    @Test("등록한 후보를 그대로 읽는다")
    func appendThenLoad_roundTrips() {
        // given
        let repository = self.makeRepository()
        let candidates: [DDayCandidate] = [
            .init(scheduleId: "s1"),
            .init(scheduleId: "s2", turnKey: "1200..<1300")
        ]

        // when
        candidates.forEach { _ = repository.append($0) }
        let loaded = repository.loadCandidates()

        // then
        #expect(loaded == candidates)
    }

    @Test("등록 결과로 갱신된 전체 목록을 낸다")
    func append_returnsWholeList() {
        // given
        let repository = self.makeRepository()
        _ = repository.append(.init(scheduleId: "s1"))

        // when
        let appended = repository.append(.init(scheduleId: "s2"))

        // then
        #expect(appended == [.init(scheduleId: "s1"), .init(scheduleId: "s2")])
    }

    @Test("같은 후보를 다시 등록해도 중복되지 않는다")
    func append_whenAlreadyStored_doesNotDuplicate() {
        // given
        let repository = self.makeRepository()
        let candidate = DDayCandidate(scheduleId: "s1", turnKey: "300")
        _ = repository.append(candidate)

        // when
        let appended = repository.append(candidate)

        // then
        #expect(appended == [candidate])
        #expect(repository.loadCandidates() == [candidate])
    }

    @Test("같은 일정의 다른 회차는 별개로 등록된다")
    func append_whenSameScheduleDifferentTurn_keepsBoth() {
        // given
        let repository = self.makeRepository()
        _ = repository.append(.init(scheduleId: "s1", turnKey: "300"))

        // when
        let appended = repository.append(.init(scheduleId: "s1", turnKey: "900"))

        // then
        #expect(appended.count == 2)
    }

    @Test("제거 결과로 남은 전체 목록을 낸다")
    func remove_returnsRemaining() {
        // given
        let repository = self.makeRepository()
        _ = repository.append(.init(scheduleId: "s1"))
        _ = repository.append(.init(scheduleId: "s2"))

        // when
        let remain = repository.remove(.init(scheduleId: "s1"))

        // then
        #expect(remain == [.init(scheduleId: "s2")])
        #expect(repository.loadCandidates() == [.init(scheduleId: "s2")])
    }

    @Test("저장된 게 없으면 빈 배열을 낸다")
    func loadCandidates_whenEmpty_returnsEmpty() {
        // given
        let repository = self.makeRepository()

        // when
        let loaded = repository.loadCandidates()

        // then
        #expect(loaded.isEmpty == true)
    }

    @Test("마지막 후보를 제거하면 전부 비워진다")
    func remove_whenLastOne_clearsAll() {
        // given
        let repository = self.makeRepository()
        _ = repository.append(.init(scheduleId: "s1"))

        // when
        let remain = repository.remove(.init(scheduleId: "s1"))

        // then
        #expect(remain.isEmpty == true)
        #expect(repository.loadCandidates().isEmpty == true)
    }
}
