//
//  AIAgentKeyboardInputViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 7/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Domain
import UnitTestHelpKit

@testable import AIAgentScene


class AIAgentKeyboardInputViewModelImpleTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!
    private var stubAgent: StubAIAgentOrchestrationUsecase!

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubAgent = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubAgent = nil
    }

    private func makeViewModel() -> AIAgentKeyboardInputViewModelImple {
        return AIAgentKeyboardInputViewModelImple(
            aiAgentOrchestrationUsecase: self.stubAgent
        )
    }
}


// MARK: - usage 노출·갱신

extension AIAgentKeyboardInputViewModelImpleTests {

    func test_prepare_refreshUsage() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.prepare()
        // then
        XCTAssertEqual(self.stubAgent.didLoadUsage, true)
    }

    func test_usage_emitsCurrentUsage() {
        // given
        let viewModel = self.makeViewModel()
        self.stubAgent.usageSubject.send(.init(input: 100, output: 200, limit: 5000))
        var usage: AIAgentUsage?
        // when
        viewModel.usage
            .sink(receiveValue: { usage = $0 })
            .store(in: &self.cancelBag)
        // then — CurrentValueSubject replay라 동기 방출
        XCTAssertEqual(usage?.inputTokens, 100)
        XCTAssertEqual(usage?.outputTokens, 200)
        XCTAssertEqual(usage?.dailyLimit, 5000)
    }
}
