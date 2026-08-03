//
//  AIAgentUsageUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine
import Extensions
import UnitTestHelpKit

@testable import Domain


final class AIAgentUsageUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []

    private func makeUsecase(
        shouldFailFirstLoadOnly: Bool = false
    ) -> AIAgentUsageUsecaseImple {
        let repository = PrivateStubRepository()
        if shouldFailFirstLoadOnly {
            repository.stubResults = [
                .failure(RuntimeError("failed")),
                .success(.init(input: 1, output: 1, limit: 1)),
                .success(.init(input: 2, output: 2, limit: 2))
            ]
        } else {
            repository.stubResults = (0..<10).map {
                .success(.init(input: $0, output: $0, limit: $0))
            }
        }
        return AIAgentUsageUsecaseImple(
            repository: repository,
            sharedDataStore: .init()
        )
    }
}


// MARK: - loadUsage

extension AIAgentUsageUsecaseImpleTests {

    // loadUsage
    @Test func usecase_loadUsage() async throws {
        // given
        let usecase = self.makeUsecase()

        // when
        let usage = try await usecase.loadUsage()

        // then
        #expect(usage.dailyLimit == 0)
    }

    // loadUsage시 currentUsage 업데이트됨
    @Test func usecase_whenAfterLoadUsage_updateCurrentUsage() async throws {
        // given
        let expect = expectConfirm("loadUsage 후 currentUsage 방출")
        expect.count = 2
        let usecase = self.makeUsecase()

        // when
        let usages = try await self.outputs(expect, for: usecase.currentUsage) {
            _ = try await usecase.loadUsage()
            
            try await Task.sleep(for: .milliseconds(50))
            
            _ = try await usecase.loadUsage()
        }

        // then
        #expect(usages.map { $0.dailyLimit } == [0, 1])
    }
}


// MARK: - refresh

extension AIAgentUsageUsecaseImpleTests {

    // refresh시에 currentUsage 업데이트됨
    @Test func usecase_whenRefresh_updateCurrentUsage() async throws {
        // given
        let expect = expectConfirm("refresh 후 currentUsage 방출")
        expect.count = 2
        let usecase = self.makeUsecase()

        // when
        let usages = try await self.outputs(expect, for: usecase.currentUsage) {
            usecase.refresh()
            
            try await Task.sleep(for: .milliseconds(50))
            
            usecase.refresh()
        }

        // then
        #expect(usages.map { $0.dailyLimit } == [0, 1])
    }

    // refresh시에 조회 실패해도 무시하고 다음번 refresh에서 성공하는 케이스
    @Test func usecase_whenRefreshFailAndRefreshAgain_updateCurrentUsageWithSuccess() async throws {
        // given
        let expect = expectConfirm("첫 refresh는 실패해 무시되고 다음 refresh 성공시 방출")
        let usecase = self.makeUsecase(shouldFailFirstLoadOnly: true)

        // when
        let usages = try await self.outputs(expect, for: usecase.currentUsage) {
            usecase.refresh()
            try await Task.sleep(for: .milliseconds(50))
            usecase.refresh()
        }

        // then
        #expect(usages.map { $0.dailyLimit } == [1])
    }
}


private final class PrivateStubRepository: BaseStubAICommandRepository, @unchecked Sendable {

    var stubResults: [Result<AIAgentUsage, any Error>] = []

    override func loadUsage() async throws -> AIAgentUsage {
        guard !self.stubResults.isEmpty
        else {
            throw RuntimeError("failed")
        }
        let first = self.stubResults.removeFirst()
        switch first {
        case .success(let usage): return usage
        case .failure(let error): throw error
        }
    }
}
