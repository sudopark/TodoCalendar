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
        authStatus: SpeechRecognizeAuthStatus = .authorized,
        startError: (any Error)? = nil
    ) -> (SpeechRecognizeUsecaseImple<DispatchQueue>, StubSpeechRecognizeService) {
        let service = StubSpeechRecognizeService()
        service.startError = startError
        let permission = StubSpeechRecognizePermissionChecker()
        permission.status = authStatus
        let usecase = SpeechRecognizeUsecaseImple(
            service: service,
            permissionChecker: permission,
            scheduler: DispatchQueue.main
        )
        return (usecase, service)
    }
}

extension SpeechRecognizeUsecaseImpleTests {

    // 권한 OK + 명시적 stop → 마지막 fragment text 방출
    @Test func usecase_whenStopListening_emitLatestRecognizedText() async throws {
        // given
        let expect = expectConfirm("stop 시 마지막 인식 텍스트 방출")
        let (usecase, service) = self.makeUsecase()

        // when
        let texts = try await self.outputs(expect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: nil)
            try await Task.sleep(for: .milliseconds(20))
            service.emit(.init(text: "안녕", isFinal: false))
            service.emit(.init(text: "안녕하세요", isFinal: false))
            try await Task.sleep(for: .milliseconds(20))
            usecase.stopListening()
        }

        // then
        #expect(texts == ["안녕하세요"])
        #expect(service.didStop == true)
    }

    // 권한 denied → notAuthorized 에러 방출, service.start 미호출
    @Test func usecase_whenNotAuthorized_emitNotAuthorizedError() async throws {
        // given
        let expect = expectConfirm("권한 거부 시 notAuthorized 에러")
        let (usecase, service) = self.makeUsecase(authStatus: .denied)

        // when
        let error = try await self.failure(expect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: nil)
            try await Task.sleep(for: .milliseconds(30))
        }

        // then
        #expect(error as? SpeechRecognizeFailReason == .notAuthorized)
        #expect(service.didStart == false)
    }

    // service.start가 throw → 해당 에러 전파
    @Test func usecase_whenServiceStartThrows_propagateError() async throws {
        // given
        let expect = expectConfirm("service.start 실패 시 에러 전파")
        let (usecase, _) = self.makeUsecase(startError: RuntimeError("start failed"))

        // when
        let error = try await self.failure(expect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: nil)
            try await Task.sleep(for: .milliseconds(30))
        }

        // then
        #expect(error is RuntimeError)
    }

    // service가 isFinal=true fragment 방출 → 자동 종료 + 해당 text
    @Test func usecase_whenServiceEmitsFinalFragment_finishWithThatText() async throws {
        // given
        let expect = expectConfirm("isFinal fragment 시 자동 종료")
        let (usecase, service) = self.makeUsecase()

        // when
        let texts = try await self.outputs(expect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: nil)
            try await Task.sleep(for: .milliseconds(20))
            service.emit(.init(text: "최종 텍스트", isFinal: true))
        }

        // then
        #expect(texts == ["최종 텍스트"])
        #expect(service.didStop == true)
    }

    // fragment 한 번도 안 온 채 stop → 빈 문자열
    @Test func usecase_whenStopWithoutFragment_emitEmptyString() async throws {
        // given
        let expect = expectConfirm("입력 없이 stop 시 빈 문자열")
        let (usecase, _) = self.makeUsecase()

        // when
        let texts = try await self.outputs(expect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: nil)
            try await Task.sleep(for: .milliseconds(20))
            usecase.stopListening()
        }

        // then
        #expect(texts == [""])
    }

    // autoStop 경과 + voice inactive → 마지막 text로 즉시 종료
    @Test func usecase_whenSilenceTimeoutAndVoiceInactive_finishWithLatestText() async throws {
        // given
        let expect = expectConfirm("침묵 타임아웃 + 소리 없음 → 즉시 종료")
        let (usecase, service) = self.makeUsecase()
        service.setVoiceActive(false)

        // when
        let texts = try await self.outputs(expect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: 0.05)
            try await Task.sleep(for: .milliseconds(20))
            service.emit(.init(text: "타임아웃 텍스트", isFinal: false))
            try await Task.sleep(for: .milliseconds(120))   // 50ms 침묵 경과
        }

        // then
        #expect(texts == ["타임아웃 텍스트"])
        #expect(service.didStop == true)
    }

    // autoStop 경과 + voice active → 즉시 종료 안 함, 이후 fragment로 종료
    @Test func usecase_whenSilenceTimeoutButVoiceActive_waitNextFragment() async throws {
        // given
        let expect = expectConfirm("침묵 타임아웃이지만 발화 중 → 다음 fragment로 종료")
        let (usecase, service) = self.makeUsecase()
        service.setVoiceActive(true)   // 아직 발화 중

        // when
        let texts = try await self.outputs(expect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: 0.05)
            try await Task.sleep(for: .milliseconds(20))
            service.emit(.init(text: "중간", isFinal: false))
            try await Task.sleep(for: .milliseconds(120))   // 타임아웃 떴지만 voiceActive라 대기
            service.emit(.init(text: "중간 그리고 끝", isFinal: false))   // 이게 종료 신호
            try await Task.sleep(for: .milliseconds(20))
        }

        // then
        #expect(texts == ["중간 그리고 끝"])
        #expect(service.didStop == true)
    }

    // 에러 종료된 세션 후 재 startListening → fresh result 스트림으로 정상 동작
    @Test func usecase_afterErrorSession_restartWorksWithFreshStream() async throws {
        // given
        let (usecase, service) = self.makeUsecase()

        // when: 1st 세션 — start 에러로 종료
        let errExpect = expectConfirm("1차 세션 에러")
        let error = try await self.failure(errExpect, for: usecase.result) {
            service.startError = RuntimeError("first fail")
            usecase.startListening(autoStopAfterSilence: nil)
            try await Task.sleep(for: .milliseconds(30))
        }
        #expect(error is RuntimeError)

        // when: 2nd 세션 — 정상 동작
        service.startError = nil
        let okExpect = expectConfirm("2차 세션 정상 텍스트")
        let texts = try await self.outputs(okExpect, for: usecase.result) {
            usecase.startListening(autoStopAfterSilence: nil)
            try await Task.sleep(for: .milliseconds(20))
            service.emit(.init(text: "재시작 텍스트", isFinal: false))
            try await Task.sleep(for: .milliseconds(20))
            usecase.stopListening()
        }

        // then
        #expect(texts == ["재시작 텍스트"])
    }
}


// MARK: - Stubs

private final class StubSpeechRecognizeService: SpeechRecognizeService, @unchecked Sendable {

    private let recognizedSubject = PassthroughSubject<SpeechRecognizeFragment, any Error>()
    private let voiceActiveSubject = CurrentValueSubject<Bool, Never>(false)

    var startError: (any Error)?
    private(set) var didStart: Bool = false
    private(set) var didStop: Bool = false

    var recognized: AnyPublisher<SpeechRecognizeFragment, any Error> {
        return self.recognizedSubject.eraseToAnyPublisher()
    }
    var isVoiceActive: AnyPublisher<Bool, Never> {
        return self.voiceActiveSubject.eraseToAnyPublisher()
    }
    func start() throws {
        if let startError { throw startError }
        self.didStart = true
    }
    func stop() {
        self.didStop = true
    }

    // test control
    func emit(_ fragment: SpeechRecognizeFragment) {
        self.recognizedSubject.send(fragment)
    }
    func emitError(_ error: any Error) {
        self.recognizedSubject.send(completion: .failure(error))
    }
    func setVoiceActive(_ active: Bool) {
        self.voiceActiveSubject.send(active)
    }
}

private final class StubSpeechRecognizePermissionChecker: SpeechRecognizePermissionChecker, @unchecked Sendable {

    var status: SpeechRecognizeAuthStatus = .authorized
    var grantAccess: Bool = true

    func checkAuthorizationStatus() async -> SpeechRecognizeAuthStatus {
        return self.status
    }
    func requestAccess() async throws -> Bool {
        return self.grantAccess
    }
}
