//
//  AIAgentKeyboardInputViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit

@testable import AIAgentScene


final class AIAgentKeyboardInputViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let stubAgent: StubAIAgentOrchestrationUsecase = .init()

    private func makeViewModel(userPlan: BillingUserPlan? = nil) -> AIAgentKeyboardInputViewModelImple {
        return AIAgentKeyboardInputViewModelImple(
            aiAgentOrchestrationUsecase: self.stubAgent,
            billingUsecase: StubBillingUsecase(stubUserPlan: userPlan)
        )
    }
}


// MARK: - usage 노출·갱신

extension AIAgentKeyboardInputViewModelImpleTests {

    @Test func viewModel_whenPrepare_refreshUsage() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.prepare()
        // then
        #expect(self.stubAgent.didLoadUsage == true)
    }

    @Test func viewModel_usage_emitsCurrentUsage() async throws {
        // given
        let expect = expectConfirm("현재 usage 방출")
        let viewModel = self.makeViewModel()
        self.stubAgent.usageSubject.send(.init(input: 100, output: 200, limit: 5000))
        // when
        let usage = try await self.firstOutput(expect, for: viewModel.usage)
        // then
        #expect(usage?.inputTokens == 100)
        #expect(usage?.outputTokens == 200)
        #expect(usage?.dailyLimit == 5000)
    }
}


// MARK: - currentUserPlan 릴레이 (#739)

extension AIAgentKeyboardInputViewModelImpleTests {

    // seeding 전(prepend nil) + billingUsecase 값 순서로 방출
    @Test func viewModel_relaysCurrentUserPlan() async throws {
        // given
        let expect = expectConfirm("currentUserPlan 을 릴레이한다")
        expect.count = 2
        let viewModel = self.makeViewModel(userPlan: BillingUserPlan() |> \.planId .~ .standard)
        // when
        let plans = try await self.outputs(expect, for: viewModel.currentUserPlan)
        // then
        #expect(plans.map { $0?.planId } == [nil, .standard])
    }
}
