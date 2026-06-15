//
//  AIAgentInputViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Domain
import Extensions
import UnitTestHelpKit

@testable import AIAgentScene


class AIAgentInputViewModelImpleTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!
    private var stubSpeech: StubSpeechRecognizeUsecase!
    private var spyListener: SpyAIAgentInputListener!

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubSpeech = .init()
        self.spyListener = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubSpeech = nil
        self.spyListener = nil
    }

    private func makeViewModel() -> AIAgentInputViewModelImple {
        let viewModel = AIAgentInputViewModelImple(speechRecognizeUsecase: self.stubSpeech)
        viewModel.listener = self.spyListener
        return viewModel
    }

    private func observeInput(_ viewModel: any AIAgentInputViewModel) -> () -> AIAgentInputState? {
        var last: AIAgentInputState?
        viewModel.inputState
            .sink(receiveValue: { last = $0 })
            .store(in: &self.cancelBag)
        return { last }
    }
}


// MARK: - 음성/키보드 전환

extension AIAgentInputViewModelImpleTests {

    func test_startInput_startsListeningInVoiceState() {
        // given
        let viewModel = self.makeViewModel()
        let input = self.observeInput(viewModel)
        // when
        viewModel.startInput()
        // then
        XCTAssertEqual(self.stubSpeech.didStartListening, true)
        XCTAssertEqual(input(), .voice)
    }

    func test_recognizingText_emittedSeparatelyFromInputState() {
        // given
        let viewModel = self.makeViewModel()
        let input = self.observeInput(viewModel)
        viewModel.startInput()
        var recognizing: String?
        viewModel.recognizingText
            .sink(receiveValue: { recognizing = $0 })
            .store(in: &self.cancelBag)
        // when
        self.stubSpeech.recognizingTextSubject.send("회의")
        // then — 텍스트는 별도 스트림으로 흐르고 inputState는 .voice 유지
        XCTAssertEqual(recognizing, "회의")
        XCTAssertEqual(input(), .voice)
    }

    func test_switchToKeyboard_stopsListeningAndShowsTextInput() {
        // given
        let viewModel = self.makeViewModel()
        let input = self.observeInput(viewModel)
        viewModel.startInput()
        // when
        viewModel.switchToKeyboard()
        // then
        XCTAssertEqual(self.stubSpeech.didStopListening, true)
        XCTAssertEqual(input(), .textInput)
    }

    func test_switchToVoice_startsListening() {
        // given
        let viewModel = self.makeViewModel()
        let input = self.observeInput(viewModel)
        // when
        viewModel.switchToVoice()
        // then
        XCTAssertEqual(input(), .voice)
        XCTAssertEqual(self.stubSpeech.didStartListening, true)
    }

    func test_stopInput_stopsListening() {
        let viewModel = self.makeViewModel()
        viewModel.stopInput()
        XCTAssertEqual(self.stubSpeech.didStopListening, true)
    }

    func test_finishVoiceInput_callsFinishListening() {
        let viewModel = self.makeViewModel()
        viewModel.startInput()
        viewModel.finishVoiceInput()
        XCTAssertEqual(self.stubSpeech.didFinishListening, true)
    }
}


// MARK: - 입력 완료 / 에러 → listener 통지

extension AIAgentInputViewModelImpleTests {

    func test_whenRecognizeResultSuccess_notifiesListener() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.startInput()
        // when
        self.stubSpeech.recognizeResultSubject.send(.success("내일 회의"))
        // then
        XCTAssertEqual(self.spyListener.didCompleteText, "내일 회의")
    }

    func test_submit_notifiesListener() {
        let viewModel = self.makeViewModel()
        viewModel.submit("키보드 입력")
        XCTAssertEqual(self.spyListener.didCompleteText, "키보드 입력")
    }

    func test_whenAuthError_inputIsPermissionDenied() {
        // given
        let viewModel = self.makeViewModel()
        let input = self.observeInput(viewModel)
        viewModel.startInput()
        // when
        self.stubSpeech.recognizeResultSubject.send(
            .failure(SpeechRecognizeAuthError(micNotAvail: .denied))
        )
        // then
        XCTAssertEqual(input(), .permissionDenied)
    }

    func test_whenNonAuthError_notifiesListenerFail() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.startInput()
        // when
        self.stubSpeech.recognizeResultSubject.send(
            .failure(RuntimeError("recognition failed"))
        )
        // then
        XCTAssertNotNil(self.spyListener.didFailError)
    }

    func test_openSystemSetting_notifiesListener() {
        let viewModel = self.makeViewModel()
        viewModel.openSystemSetting()
        XCTAssertEqual(self.spyListener.didRequestSystemSetting, true)
    }
}
