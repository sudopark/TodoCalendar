//
//  SpeechRecognizeUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Combine
import UnitTestHelpKit
import Extensions

@testable import Domain


class SpeechRecognizeUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []

    private func makeUsecase(
        autoStopAfterSilence: TimeInterval = 3,
        accessError: (any Error)? = nil,
        startError: (any Error)? = nil
    ) -> (SpeechRecognizeUsecaseImple, StubSpeechRecognizeService) {
        let service = StubSpeechRecognizeService()
        service.startError = startError
        let permission = StubSpeechRecognizePermissionChecker()
        permission.accessError = accessError
        let usecase = SpeechRecognizeUsecaseImple(
            service: service,
            permissionChecker: permission,
            autoStopAfterSilence: autoStopAfterSilence
        )
        return (usecase, service)
    }

    private func captureResult(
        for usecase: SpeechRecognizeUsecaseImple,
        timeout: Duration = .milliseconds(150),
        _ action: () async throws -> Void
    ) async throws -> Result<String, any Error>? {
        let box = ResultBox()
        usecase.recognizeResult
            .sink { box.value = $0 }
            .store(in: &self.cancelBag)
        try await action()
        try await Task.sleep(for: timeout)
        return box.value
    }
}


// MARK: - 음성 인식 결과

extension SpeechRecognizeUsecaseImpleTests {

    @Test func usecase_whenUserFinishesSpeaking_emitsRecognizedText() async throws {
        // given
        let (usecase, service) = self.makeUsecase()

        // when
        let captured = try await self.captureResult(for: usecase) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(50))
            service.emit(.init(text: "안녕하세요", isFinal: true))
        }

        // then
        let result = try #require(captured)
        guard case .success(let text) = result else {
            Issue.record("성공 결과가 아님")
            return
        }
        #expect(text == "안녕하세요")
    }

    @Test func usecase_whenUserKeepsSpeaking_emitsFinalText() async throws {
        // given
        let (usecase, service) = self.makeUsecase()

        // when
        let captured = try await self.captureResult(for: usecase) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(50))
            service.emit(.init(text: "오늘", isFinal: false))
            service.emit(.init(text: "오늘 일정", isFinal: false))
            service.emit(.init(text: "오늘 일정 추가", isFinal: false))
            service.emit(.init(text: "오늘 일정 추가해줘", isFinal: true))
        }

        // then
        let result = try #require(captured)
        guard case .success(let text) = result else {
            Issue.record("성공 결과가 아님")
            return
        }
        #expect(text == "오늘 일정 추가해줘")
    }

    @Test func usecase_whenUserPausesAfterSpeaking_emitsRecognizedTextSoFar() async throws {
        // given
        let (usecase, service) = self.makeUsecase(autoStopAfterSilence: 0.1)

        // when
        let captured = try await self.captureResult(for: usecase) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(50))
            service.emit(.init(text: "오늘 일정", isFinal: false))
            try await Task.sleep(for: .milliseconds(200))
        }

        // then
        let result = try #require(captured)
        guard case .success(let text) = result else {
            Issue.record("성공 결과가 아님")
            return
        }
        #expect(text == "오늘 일정")
    }

    @Test func usecase_whenPermissionDenied_emitsFailure() async throws {
        // given
        let (usecase, _) = self.makeUsecase(
            accessError: SpeechRecognizeAuthError(micNotAvail: .denied)
        )

        // when
        let captured = try await self.captureResult(for: usecase) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(80))
        }

        // then
        let result = try #require(captured)
        guard case .failure(let error) = result else {
            Issue.record("실패 결과가 아님")
            return
        }
        let authError = try #require(error as? SpeechRecognizeAuthError)
        guard case .denied? = authError.micNotAvail else {
            Issue.record("micNotAvail이 denied가 아님")
            return
        }
        #expect(authError.speechNotAvail == nil)
    }

    @Test func usecase_whenListeningCannotStart_emitsFailure() async throws {
        // given
        let startError = RuntimeError(key: "engineStartFail", "audio engine could not start")
        let (usecase, _) = self.makeUsecase(startError: startError)

        // when
        let captured = try await self.captureResult(for: usecase) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(80))
        }

        // then
        let result = try #require(captured)
        guard case .failure(let error) = result else {
            Issue.record("실패 결과가 아님")
            return
        }
        let runtimeError = try #require(error as? RuntimeError)
        #expect(runtimeError.key == "engineStartFail")
        #expect(runtimeError.message == "audio engine could not start")
    }

    @Test func usecase_whenRecognitionFails_emitsFailure() async throws {
        // given
        let (usecase, service) = self.makeUsecase()

        // when
        let captured = try await self.captureResult(for: usecase) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(50))
            service.emitError(RuntimeError("recognition interrupted"))
        }

        // then
        let result = try #require(captured)
        guard case .failure = result else {
            Issue.record("실패 결과가 아님")
            return
        }
    }
}


// MARK: - 듣기 상태와 입력 레벨

extension SpeechRecognizeUsecaseImpleTests {

    @Test func usecase_whenNotListening_hasNoInputLevel() async throws {
        // given
        let (usecase, _) = self.makeUsecase()

        // when
        let value = try await self.firstOutput(
            expectConfirm("듣고 있지 않을 때"), for: usecase.isRecognizingWithLevel
        )

        // then
        guard case .some(let level) = value else {
            Issue.record("방출이 없었음")
            return
        }
        #expect(level == nil)
    }

    @Test func usecase_whileListening_providesInputLevels() async throws {
        // given
        let expect = expectConfirm("듣는 동안 입력 레벨")
        expect.count = 5
        let (usecase, service) = self.makeUsecase()

        // when
        let levels = try await self.outputs(expect, for: usecase.isRecognizingWithLevel) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(60))
            service.sendLevel(0.3)
            service.sendLevel(0.6)
            service.sendLevel(0.9)
            try await Task.sleep(for: .milliseconds(40))
        }

        // then
        #expect(levels == [nil, 0.0, 0.3, 0.6, 0.9])
    }

    @Test func usecase_whenSilentWithoutSpeech_stopsListening() async throws {
        // given
        let expect = expectConfirm("발화 없이 침묵이 지속될 때")
        expect.count = 3
        let (usecase, _) = self.makeUsecase(autoStopAfterSilence: 0.1)

        // when
        let levels = try await self.outputs(expect, for: usecase.isRecognizingWithLevel) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(250))
        }

        // then
        #expect(levels.last == .some(nil))
    }
}


// MARK: - 중복 시작 방지

extension SpeechRecognizeUsecaseImpleTests {

    @Test func usecase_whenAlreadyListening_ignoresStart() async throws {
        // given
        let expect = expectConfirm("이미 듣는 중에 다시 시작")
        expect.count = 3
        let (usecase, service) = self.makeUsecase()

        // when
        let levels = try await self.outputs(expect, for: usecase.isRecognizingWithLevel) {
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(60))
            service.sendLevel(0.5)
            try await Task.sleep(for: .milliseconds(30))
            usecase.startListening()
            try await Task.sleep(for: .milliseconds(40))
        }

        // then
        #expect(levels == [nil, 0.0, 0.5])
    }
}


// MARK: - test doubles

private final class ResultBox: @unchecked Sendable {
    var value: Result<String, any Error>?
}

private final class StubSpeechRecognizeService: SpeechRecognizeService, @unchecked Sendable {

    private let recognizedSubject = PassthroughSubject<SpeechRecognizeFragment, any Error>()
    private let voiceLevelSubject = CurrentValueSubject<Float, Never>(0)

    var startError: (any Error)?

    var recognized: AnyPublisher<SpeechRecognizeFragment, any Error> {
        return self.recognizedSubject.eraseToAnyPublisher()
    }
    var voiceLevel: AnyPublisher<Float, Never> {
        return self.voiceLevelSubject.eraseToAnyPublisher()
    }
    func start() throws {
        if let startError { throw startError }
    }
    func stop() { }

    func emit(_ fragment: SpeechRecognizeFragment) {
        self.recognizedSubject.send(fragment)
    }
    func emitError(_ error: any Error) {
        self.recognizedSubject.send(completion: .failure(error))
    }
    func sendLevel(_ level: Float) {
        self.voiceLevelSubject.send(level)
    }
}

private final class StubSpeechRecognizePermissionChecker: SpeechRecognizePermissionChecker, @unchecked Sendable {

    var accessError: (any Error)?

    func requestAccess() async throws {
        if let accessError { throw accessError }
    }
}
