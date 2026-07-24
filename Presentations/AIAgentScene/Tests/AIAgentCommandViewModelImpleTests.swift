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
    private var spyRouter: SpyAIAgentRouter!

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubAgent = .init()
        self.spyRouter = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubAgent = nil
        self.spyRouter = nil
    }

    private func makeViewModel() -> AIAgentCommandViewModelImple {
        let viewModel = AIAgentCommandViewModelImple(orchestrationUsecase: self.stubAgent)
        viewModel.router = self.spyRouter
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


// MARK: - 시트 액션과 orchestration 위임

extension AIAgentCommandViewModelImpleTests {

    func test_sendCommand_delegatesToUsecase() {
        let viewModel = self.makeViewModel()
        viewModel.sendCommand("회의")
        XCTAssertEqual(self.stubAgent.didSubmit, "회의")
    }

    func test_confirm_delegatesAndKeepsSceneOpen() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.confirm()
        // then
        XCTAssertEqual(self.stubAgent.didConfirm, true)
        XCTAssertNil(self.spyRouter.didClosed)   // confirm은 시트 유지(처리 계속)
    }

    func test_decline_declinesAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.decline()
        // then
        XCTAssertEqual(self.stubAgent.didDecline, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }

    func test_cancel_showsStopConfirmDialog() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.cancel()
        // then — 즉시 중지하지 않고 확인 팝업부터 노출
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
    }

    func test_cancel_whenConfirmed_resetsAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        self.spyRouter.shouldConfirmNotCancel = true   // 팝업에서 '중지' 선택
        // when
        viewModel.cancel()
        // then
        XCTAssertEqual(self.stubAgent.didReset, true)   // reset → 서버 cancel API
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }

    func test_cancel_whenDialogDismissed_doesNotResetNorClose() {
        // given
        let viewModel = self.makeViewModel()
        self.spyRouter.shouldConfirmNotCancel = false   // 팝업에서 '취소' 선택
        // when
        viewModel.cancel()
        // then — 확인 안 하면 중지 안 되고 시트도 유지
        XCTAssertFalse(self.stubAgent.didReset)
        XCTAssertNil(self.spyRouter.didClosed)
    }

    func test_acknowledge_resetsAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.acknowledge()
        // then — 팝업 없이 바로 reset(idle) + 닫기
        XCTAssertEqual(self.stubAgent.didReset, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }

    func test_close_keepsStateAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.close()
        // then — 상태 보존(orchestration 안 건드림), 시트만 닫음
        XCTAssertFalse(self.stubAgent.didReset)
        XCTAssertFalse(self.stubAgent.didDecline)
        XCTAssertEqual(self.spyRouter.didClosed, true)
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
        self.stubAgent.stateSubject.send(.done(command: "회의 추가", message: "완료"))
        XCTAssertEqual(command(), .done(command: "회의 추가", message: "완료"))
    }

    func test_whenOrchestratorFailed_commandStateCarriesErrorCode() {
        // given
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        // when
        self.stubAgent.stateSubject.send(
            .failed(command: "회의", reason: "오늘 사용량을 모두 썼어요", errorCode: .dailyLimitExceeded)
        )
        // then
        XCTAssertEqual(command(), .failed(command: "회의", reason: "오늘 사용량을 모두 썼어요", errorCode: .dailyLimitExceeded))
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
