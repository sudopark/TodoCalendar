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
