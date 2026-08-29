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
import Prelude
import Optics
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


// MARK: - billingUserPlan 시딩 (I1)
//
// AIAgentUsageUsecaseImple.loadUsage() 가 sharedDataStore 에 넣는 billingUserPlan 은 프로덕션에서
// paywall 의 currentUserPlan 이 처음 채워지는 유일한 경로다(e1a7ef3c). userPlan 이 있으면 넣고,
// nil 이면 기존 값을 지우지 않는다는 계약이 테스트 없이 남아 있었다 — 여기 깨지면 유료 유저에게
// paywall 이 조용히 "무료"를 보여준다

extension AIAgentUsageUsecaseImpleTests {

    private func makeUsecaseSeedingPlan(
        _ responseUserPlan: BillingPlanId?, seeded: BillingPlanId? = nil
    ) -> (AIAgentUsageUsecaseImple, SharedDataStore) {
        let sharedDataStore = SharedDataStore()
        seeded.map {
            sharedDataStore.put(
                BillingUserPlan.self,
                key: ShareDataKeys.billingUserPlan.rawValue,
                BillingUserPlan() |> \.planId .~ $0
            )
        }
        let repository = PrivateStubRepository()
        repository.stubResults = [.success(.init(input: 1, output: 1, limit: 1))]
        repository.stubUserPlan = responseUserPlan.map { BillingUserPlan() |> \.planId .~ $0 }
        let usecase = AIAgentUsageUsecaseImple(
            repository: repository, sharedDataStore: sharedDataStore
        )
        return (usecase, sharedDataStore)
    }

    private func seededPlanId(_ store: SharedDataStore) -> BillingPlanId? {
        return store.value(
            BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue
        )?.planId
    }

    @Test func usecase_whenLoadUsageReturnsUserPlan_seedsBillingUserPlan() async throws {
        // given
        let (usecase, store) = self.makeUsecaseSeedingPlan(.standard)

        // when
        _ = try await usecase.loadUsage()

        // then
        #expect(self.seededPlanId(store) == .standard)
    }

    // userPlan 이 nil 인 응답을 그대로 덮어쓰면, 방금 구매로 갱신된 최신 플랜이 다음 usage
    // 재조회 한 번에 지워진다 — nil 은 put 하지 않고 기존 값을 유지해야 한다
    @Test func usecase_whenLoadUsageReturnsNilUserPlan_keepsExistingBillingUserPlan() async throws {
        // given
        let (usecase, store) = self.makeUsecaseSeedingPlan(nil, seeded: .lifetime)

        // when
        _ = try await usecase.loadUsage()

        // then
        #expect(self.seededPlanId(store) == .lifetime)
    }
}


// MARK: - 캐시된 usage·plan 으로 소진 판정

extension AIAgentUsageUsecaseImpleTests {

    private func makeUsecaseWithCached(
        usage: AIAgentUsage?,
        userPlan: BillingUserPlan?
    ) -> AIAgentUsageUsecaseImple {
        let store = SharedDataStore()
        if let usage {
            store.put(AIAgentUsage.self, key: ShareDataKeys.aiAgentUsage.rawValue, usage)
        }
        if let userPlan {
            store.put(BillingUserPlan.self, key: ShareDataKeys.billingUserPlan.rawValue, userPlan)
        }
        return AIAgentUsageUsecaseImple(
            repository: PrivateStubRepository(),
            sharedDataStore: store
        )
    }

    private func exhaustedUsage() -> AIAgentUsage {
        return AIAgentUsage(input: 0, output: 0, limit: 3000)
            |> \.creditsUsed .~ 3000
    }

    @Test("캐시된 usage 가 소진이고 top-up 잔량이 없으면 소진")
    func usecase_whenCachedUsageExhaustedWithoutTopup_isExhausted() {
        // given
        let usecase = self.makeUsecaseWithCached(
            usage: self.exhaustedUsage(),
            userPlan: BillingUserPlan() |> \.topupRemaining .~ 0
        )

        // when
        let isExhausted = usecase.isCreditExhausted()

        // then
        #expect(isExhausted == true)
    }

    @Test("캐시된 usage 가 소진이어도 top-up 잔량이 있으면 소진 아님")
    func usecase_whenCachedUsageExhaustedButTopupRemains_isNotExhausted() {
        // given
        let usecase = self.makeUsecaseWithCached(
            usage: self.exhaustedUsage(),
            userPlan: BillingUserPlan() |> \.topupRemaining .~ 500
        )

        // when
        let isExhausted = usecase.isCreditExhausted()

        // then
        #expect(isExhausted == false)
    }

    @Test("캐시된 usage 가 없으면 소진 아님")
    func usecase_whenUsageNotCached_isNotExhausted() {
        // given
        let usecase = self.makeUsecaseWithCached(usage: nil, userPlan: nil)

        // when
        let isExhausted = usecase.isCreditExhausted()

        // then
        #expect(isExhausted == false)
    }

    @Test("캐시된 plan 이 없으면 소진 아님")
    func usecase_whenUserPlanNotCached_isNotExhausted() {
        // given
        let usecase = self.makeUsecaseWithCached(
            usage: self.exhaustedUsage(), userPlan: nil
        )

        // when
        let isExhausted = usecase.isCreditExhausted()

        // then
        #expect(isExhausted == false)
    }
}


private final class PrivateStubRepository: BaseStubAICommandRepository, @unchecked Sendable {

    var stubResults: [Result<AIAgentUsage, any Error>] = []
    // I1 — loadUsage() 응답에 실릴 플랜. nil 이면 "이번 응답엔 플랜 정보 없음"을 시뮬레이션
    var stubUserPlan: BillingUserPlan?

    override func loadUsage() async throws -> AIAgentUsageLoadResult {
        guard !self.stubResults.isEmpty
        else {
            throw RuntimeError("failed")
        }
        let first = self.stubResults.removeFirst()
        switch first {
        case .success(let usage): return AIAgentUsageLoadResult(usage: usage, userPlan: self.stubUserPlan)
        case .failure(let error): throw error
        }
    }
}
