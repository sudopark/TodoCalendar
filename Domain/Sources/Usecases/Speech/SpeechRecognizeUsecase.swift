//
//  SpeechRecognizeUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - SpeechRecognizeFailReason

public enum SpeechRecognizeFailReason: Error, Sendable, Equatable {
    case notAuthorized
    case recognizerUnavailable
    case recognitionFailed
}


// MARK: - SpeechRecognizeUsecase

public protocol SpeechRecognizeUsecase: Sendable {

    // 세션당 최종 텍스트 1회 방출. 에러 종료 후엔 다음 startListening이 fresh 스트림으로 교체
    var result: AnyPublisher<String, any Error> { get }

    func startListening(autoStopAfterSilence: TimeInterval?)
    func stopListening()
}


// MARK: - SpeechRecognizeUsecaseImple

public final class SpeechRecognizeUsecaseImple<Scheduler: Combine.Scheduler>: SpeechRecognizeUsecase, @unchecked Sendable {

    private let service: any SpeechRecognizeService
    private let permissionChecker: any SpeechRecognizePermissionChecker
    private let scheduler: Scheduler

    public init(
        service: any SpeechRecognizeService,
        permissionChecker: any SpeechRecognizePermissionChecker,
        scheduler: Scheduler
    ) {
        self.service = service
        self.permissionChecker = permissionChecker
        self.scheduler = scheduler
    }

    private let sessionSubject = CurrentValueSubject<PassthroughSubject<String, any Error>, Never>(.init())
    private var currentSession: PassthroughSubject<String, any Error>?
    private var serviceBag: Set<AnyCancellable> = []
    private var silenceTimer: AnyCancellable?

    private var isListening: Bool = false
    private var latestText: String = ""
    private var isVoiceActive: Bool = false
    private var autoStopAfterSilence: TimeInterval?
    private var waitingFragmentAfterSilence: Bool = false
}

extension SpeechRecognizeUsecaseImple {

    public var result: AnyPublisher<String, any Error> {
        return self.sessionSubject
            .setFailureType(to: (any Error).self)
            .map { $0.eraseToAnyPublisher() }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    public func startListening(autoStopAfterSilence: TimeInterval?) {
        self.teardownSession()
        let session = PassthroughSubject<String, any Error>()
        self.currentSession = session
        self.sessionSubject.send(session)
        self.latestText = ""
        self.isVoiceActive = false
        self.waitingFragmentAfterSilence = false
        self.autoStopAfterSilence = autoStopAfterSilence
        self.isListening = true

        Task { [weak self] in
            guard let self else { return }
            let status = await self.permissionChecker.checkAuthorizationStatus()
            guard self.isListening else { return }
            guard status == .authorized else {
                session.send(completion: .failure(SpeechRecognizeFailReason.notAuthorized))
                self.isListening = false
                self.resetSessionStream()
                return
            }
            self.bindService()
            do {
                try self.service.start()
                self.resetSilenceTimer()
            } catch {
                session.send(completion: .failure(error))
                self.isListening = false
                self.resetSessionStream()
            }
        }
    }

    public func stopListening() {
        guard self.isListening else { return }
        self.finish(with: self.latestText)
    }
}

extension SpeechRecognizeUsecaseImple {

    private func bindService() {
        self.service.recognized
            .sink(receiveCompletion: { [weak self] completion in
                guard case let .failure(error) = completion else { return }
                guard let self, self.isListening else { return }
                self.isListening = false
                self.currentSession?.send(completion: .failure(error))
                self.resetSessionStream()
            }, receiveValue: { [weak self] fragment in
                self?.handle(fragment)
            })
            .store(in: &self.serviceBag)

        self.service.isVoiceActive
            .sink(receiveValue: { [weak self] active in
                guard let self else { return }
                self.isVoiceActive = active
                if active == false, self.waitingFragmentAfterSilence {
                    self.resetSilenceTimer()
                }
            })
            .store(in: &self.serviceBag)
    }

    private func handle(_ fragment: SpeechRecognizeFragment) {
        guard self.isListening else { return }
        self.latestText = fragment.text
        if self.waitingFragmentAfterSilence {
            self.finish(with: fragment.text)
            return
        }
        if fragment.isFinal {
            self.finish(with: fragment.text)
            return
        }
        self.resetSilenceTimer()
    }

    private func resetSilenceTimer() {
        self.silenceTimer?.cancel()
        self.silenceTimer = nil
        self.waitingFragmentAfterSilence = false
        guard let autoStop = self.autoStopAfterSilence else { return }
        self.silenceTimer = Just(())
            .delay(for: .seconds(autoStop), scheduler: self.scheduler)
            .sink(receiveValue: { [weak self] in self?.onSilenceTimeout() })
    }

    private func onSilenceTimeout() {
        guard self.isListening else { return }
        if self.isVoiceActive {
            self.waitingFragmentAfterSilence = true
        } else {
            self.finish(with: self.latestText)
        }
    }

    private func finish(with text: String) {
        guard self.isListening else { return }
        self.isListening = false
        self.teardownSessionResources()
        self.service.stop()
        self.currentSession?.send(text)
        self.currentSession?.send(completion: .finished)
    }

    private func teardownSession() {
        self.isListening = false
        self.teardownSessionResources()
    }

    // 에러로 끝난 세션은 Combine 상 terminal이라, sessionSubject의 현재값을
    // fresh placeholder로 교체해 다음 구독자가 옛 실패를 재생받지 않게 한다.
    private func resetSessionStream() {
        self.currentSession = nil
        self.sessionSubject.send(.init())
    }

    private func teardownSessionResources() {
        self.silenceTimer?.cancel()
        self.silenceTimer = nil
        self.waitingFragmentAfterSilence = false
        self.serviceBag = []
    }
}
