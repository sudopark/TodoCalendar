//
//  AIAgentCommandViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Domain
import UnitTestHelpKit

@testable import AIAgentScene


class AIAgentCommandViewModelImpleTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!
    private var stubAgent: StubAIAgentOrchestrationUsecase!
    private var spyListener: SpyAIAgentCommandListener!

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubAgent = .init()
        self.spyListener = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubAgent = nil
        self.spyListener = nil
    }

    private func makeViewModel() -> AIAgentCommandViewModelImple {
        let viewModel = AIAgentCommandViewModelImple(orchestrationUsecase: self.stubAgent)
        viewModel.listener = self.spyListener
        return viewModel
    }

    private func observeCommand(_ viewModel: any AIAgentCommandViewModel) -> () -> AIAgentCommandState?? {
        var last: AIAgentCommandState??
        viewModel.commandState
            .sink(receiveValue: { last = $0 })
            .store(in: &self.cancelBag)
        return { last }
    }
}


// MARK: - 위임

extension AIAgentCommandViewModelImpleTests {

    func test_sendCommand_delegatesToUsecase() {
        let viewModel = self.makeViewModel()
        viewModel.sendCommand("회의")
        XCTAssertEqual(self.stubAgent.didSendCommand, "회의")
    }

    func test_confirm_delegatesToUsecase() {
        let viewModel = self.makeViewModel()
        viewModel.confirm()
        XCTAssertEqual(self.stubAgent.didConfirm, true)
    }

    func test_decline_delegatesToUsecase() {
        let viewModel = self.makeViewModel()
        viewModel.decline()
        XCTAssertEqual(self.stubAgent.didDecline, true)
    }

    func test_restart_resetsUsecase() {
        let viewModel = self.makeViewModel()
        viewModel.restart()
        XCTAssertEqual(self.stubAgent.didReset, true)
    }

    func test_close_requestsCloseToListener() {
        let viewModel = self.makeViewModel()
        viewModel.close()
        XCTAssertEqual(self.spyListener.didRequestClose, true)
    }
}


// MARK: - commandState 매핑

extension AIAgentCommandViewModelImpleTests {

    func test_whenOrchestratorIdle_commandStateIsNil() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        self.stubAgent.stateSubject.send(.idle)
        XCTAssertEqual(command(), .some(.none))
    }

    func test_whenOrchestratorProcessing_commandStateIsProcessing() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        self.stubAgent.stateSubject.send(.processing(command: "회의"))
        XCTAssertEqual(command(), .processing(command: "회의"))
    }

    func test_whenOrchestratorConfirm_commandStateCarriesMessage() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        self.stubAgent.stateSubject.send(
            .confirm(command: "삭제", message: "정말?", action: AIConfirmCommandAction())
        )
        XCTAssertEqual(command(), .confirm(command: "삭제", message: "정말?"))
    }

    func test_whenOrchestratorDone_commandStateIsDone() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        self.stubAgent.stateSubject.send(.done(message: "완료"))
        XCTAssertEqual(command(), .done(message: "완료"))
    }

    func test_beforeOrchestratorDetermined_emitsNothing() {
        let viewModel = self.makeViewModel()
        var emitted: [AIAgentCommandState?] = []
        viewModel.commandState
            .sink(receiveValue: { emitted.append($0) })
            .store(in: &self.cancelBag)
        XCTAssertTrue(emitted.isEmpty)
    }
}
