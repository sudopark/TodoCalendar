//
//  GuideTodoUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Foundation
import UnitTestHelpKit

@testable import Domain


final class GuideTodoUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private final class StubRepository: GuideTodoRepository, @unchecked Sendable {

        private var isCompleted: Bool
        var didMarkCompleted: Bool = false

        init(isCompleted: Bool) {
            self.isCompleted = isCompleted
        }

        func loadIsCompleted() -> Bool {
            return self.isCompleted
        }

        func markCompleted() {
            self.didMarkCompleted = true
            self.isCompleted = true
        }
    }

    private func makeUsecase(
        isCompleted: Bool = false,
        repository: StubRepository? = nil
    ) -> GuideTodoUsecaseImple {
        return GuideTodoUsecaseImple(
            repository: repository ?? StubRepository(isCompleted: isCompleted),
            sharedDataStore: SharedDataStore(serialEventQeueu: nil)
        )
    }
}


// MARK: - 노출 여부

extension GuideTodoUsecaseImpleTests {

    @Test("prepare 전에는 안내할일이 보이지 않는다")
    func isGuideTodoVisible_beforePrepare_emitsFalse() async throws {
        // given
        let expect = expectConfirm("비노출 방출")
        let usecase = self.makeUsecase(isCompleted: false)

        // when
        let isVisible = try await self.firstOutput(expect, for: usecase.isGuideTodoVisible)

        // then
        #expect(isVisible == false)
    }

    @Test("prepare 하면 완료 기록이 없을 때 안내할일이 보인다")
    func prepare_whenNotCompleted_showsGuideTodo() async throws {
        // given
        let expect = expectConfirm("비노출 -> 노출")
        expect.count = 2
        let usecase = self.makeUsecase(isCompleted: false)

        // when
        let isVisibles = try await self.outputs(expect, for: usecase.isGuideTodoVisible) {
            usecase.prepare()
        }

        // then
        #expect(isVisibles == [false, true])
    }

    @Test("이미 완료했으면 prepare 해도 안내할일이 보이지 않는다")
    func prepare_whenAlreadyCompleted_keepsGuideTodoHidden() async throws {
        // given
        let expect = expectConfirm("비노출 유지")
        let usecase = self.makeUsecase(isCompleted: true)

        // when
        let isVisible = try await self.firstOutput(expect, for: usecase.isGuideTodoVisible) {
            usecase.prepare()
        }

        // then
        #expect(isVisible == false)
    }
}


// MARK: - 완료 처리

extension GuideTodoUsecaseImpleTests {

    @Test("완료하면 안내할일이 사라진다")
    func completeGuideTodo_hidesGuideTodo() async throws {
        // given
        let expect = expectConfirm("노출 -> 비노출")
        expect.count = 3
        let usecase = self.makeUsecase(isCompleted: false)

        // when
        let isVisibles = try await self.outputs(expect, for: usecase.isGuideTodoVisible) {
            usecase.prepare()
            usecase.completeGuideTodo()
        }

        // then
        #expect(isVisibles == [false, true, false])
    }

    @Test("완료하면 저장소에 기록한다")
    func completeGuideTodo_persistsToRepository() async throws {
        // given
        let repository = StubRepository(isCompleted: false)
        let usecase = self.makeUsecase(repository: repository)

        // when
        usecase.completeGuideTodo()

        // then
        #expect(repository.didMarkCompleted == true)
    }
}
