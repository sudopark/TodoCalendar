//
//  AIAgentKeyboardInputViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import UnitTestHelpKit

@testable import AIAgentScene


final class AIAgentKeyboardInputViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let stubAgent: StubAIAgentOrchestrationUsecase = .init()

    private func makeViewModel() -> AIAgentKeyboardInputViewModelImple {
        return AIAgentKeyboardInputViewModelImple(
            aiAgentOrchestrationUsecase: self.stubAgent
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
