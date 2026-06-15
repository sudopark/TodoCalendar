//
//  AIAgentViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Domain
import Scenes
import Extensions
import UnitTestHelpKit

@testable import AIAgentScene


class AIAgentViewModelImpleTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!
    private var stubSpeech: StubSpeechRecognizeUsecase!
    private var stubAgent: StubAIAgentOrchestrationUsecase!
    private var spyRouter: SpyAIAgentRouter!

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubSpeech = .init()
        self.stubAgent = .init()
        self.spyRouter = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubSpeech = nil
        self.stubAgent = nil
        self.spyRouter = nil
    }

    private func makeViewModel() -> AIAgentViewModelImple {
        let viewModel = AIAgentViewModelImple(
            orchestrationUsecase: self.stubAgent,
            speechRecognizeUsecase: self.stubSpeech
        )
        viewModel.router = self.spyRouter
        return viewModel
    }

    private func observeStage(_ viewModel: any AIAgentViewModel) -> () -> AIAgentStageKind? {
        var last: AIAgentStageKind?
        viewModel.stage
            .sink(receiveValue: { last = $0 })
            .store(in: &self.cancelBag)
        return { last }
    }
}


// MARK: - prepare: orchestrator 상태로 stage 분기 (메인 책임)

extension AIAgentViewModelImpleTests {

    func test_prepare_whenNoActiveCommand_showsInputAndStartsListening() {
        // given
        let viewModel = self.makeViewModel()
        let stage = self.observeStage(viewModel)
        // when
        viewModel.prepare()
        self.stubAgent.stateSubject.send(.idle)
        // then
        XCTAssertEqual(stage(), .input)
        XCTAssertEqual(self.stubSpeech.didStartListening, true)
    }

    func test_prepare_whenCommandActive_showsCommandStageWithoutMic() {
        // given
        let viewModel = self.makeViewModel()
        let stage = self.observeStage(viewModel)
        // when
        viewModel.prepare()
        self.stubAgent.stateSubject.send(.processing(command: "내일 회의"))
        // then
        XCTAssertEqual(stage(), .command)
        XCTAssertEqual(self.stubSpeech.didStartListening, false)
        XCTAssertEqual(self.stubSpeech.didStopListening, true)
    }

    func test_prepare_beforeStateDetermined_staysWaiting() {
        // given
        let viewModel = self.makeViewModel()
        var emitted: [AIAgentStageKind] = []
        viewModel.stage
            .sink(receiveValue: { emitted.append($0) })
            .store(in: &self.cancelBag)
        // when — orchestrator 상태 미확정 (복원 진행 중)
        viewModel.prepare()
        // then
        XCTAssertTrue(emitted.isEmpty)
        XCTAssertEqual(self.stubSpeech.didStartListening, false)
    }

    func test_prepare_loadsUsage() {
        let viewModel = self.makeViewModel()
        viewModel.prepare()
        XCTAssertEqual(self.stubAgent.didLoadUsage, true)
    }

    func test_usage_forwardsOrchestratorUsage() {
        // given
        let viewModel = self.makeViewModel()
        var got: AIAgentUsage?
        viewModel.usage.sink(receiveValue: { got = $0 }).store(in: &self.cancelBag)
        // when
        self.stubAgent.usageSubject.send(.init(input: 10, output: 20, limit: 100))
        // then
        XCTAssertEqual(got?.dailyLimit, 100)
    }
}


// MARK: - 입력 완료 → command 전환

extension AIAgentViewModelImpleTests {

    func test_whenInputCompletes_sendsCommandAndShowsCommandStage() {
        // given
        let viewModel = self.makeViewModel()
        let stage = self.observeStage(viewModel)
        viewModel.prepare()
        self.stubAgent.stateSubject.send(.idle)
        // when
        viewModel.inputViewModel.submit("회의 잡아줘")
        // then
        XCTAssertEqual(self.stubAgent.didSendCommand, "회의 잡아줘")
        XCTAssertEqual(stage(), .command)
    }

    func test_whenCommandResetsToIdle_returnsToInputStage() {
        // given
        let viewModel = self.makeViewModel()
        let stage = self.observeStage(viewModel)
        viewModel.prepare()
        self.stubAgent.stateSubject.send(.processing(command: "삭제"))
        // when
        self.stubAgent.stateSubject.send(.idle)
        // then
        XCTAssertEqual(stage(), .input)
    }
}


// MARK: - listener: 설정 / 에러 / 닫기

extension AIAgentViewModelImpleTests {

    func test_inputRequestSystemSetting_routes() {
        let viewModel = self.makeViewModel()
        viewModel.inputViewModel.openSystemSetting()
        XCTAssertEqual(self.spyRouter.didOpenSystemSetting, true)
    }

    func test_inputDidFail_showsError() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.inputViewModel.startInput()
        // when — 비-auth 인식 에러
        self.stubSpeech.recognizeResultSubject.send(.failure(RuntimeError("fail")))
        // then
        XCTAssertNotNil(self.spyRouter.didShowError)
    }

    func test_commandClose_stopsListeningAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.prepare()
        self.stubAgent.stateSubject.send(.idle)
        // when — command 단계 닫기 요청
        viewModel.commandViewModel.close()
        // then
        XCTAssertEqual(self.stubSpeech.didStopListening, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
}
