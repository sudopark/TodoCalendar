//
//  SpeechRecognizeServiceImple.swift
//  SpeechService
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Speech
import AVFoundation
import Extensions
import Domain


public final class SpeechRecognizeServiceImple: SpeechRecognizeService, @unchecked Sendable {

    private let recognizer: SFSpeechRecognizer?
    private let serialQueue = DispatchQueue(label: "speech-recognize-service")
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private struct Subject {
        let recognizedResult = PassthroughSubject<
            Result<SpeechRecognizeFragment, any Error>, Never
        >()
        let voiceLevel = CurrentValueSubject<Float, Never>(0)
        let audioInputDisrupted = PassthroughSubject<Void, Never>()
    }
    private let subject = Subject()
    private var audioSessionObserving = Set<AnyCancellable>()

    // 이 dBFS 이하를 0(무음)으로, 0dBFS를 1로 매핑하는 노이즈 플로어
    private let noiseFloor: Float = -50.0

    public init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    // serialQueue를 타지 않는다 — stop()의 async 블록이 마지막 참조를 놓으면 deinit이 그 큐 위에서 돌아 sync 진입이 데드락된다
    deinit {
        self.teardownAudio()
    }
}


extension SpeechRecognizeServiceImple {
    
    public func start() throws {
        try self.serialQueue.sync {
            do {
                guard let recognizer, recognizer.isAvailable else {
                    throw RuntimeError(key: "recognizerUnavailable", "speech recognizer unavailable")
                }
                try self.configureAudioSession()
                self.observeAudioDisruption()
                let request = self.makeRequest()
                self.installInputTap()
                self.task = self.makeRecognitionTask(recognizer: recognizer, request: request)
                try self.startEngine()
            } catch {
                // start 도중 실패하면 설치된 tap/세션을 되돌려 완전 초기 상태로 리셋 후 전파
                self.teardownAudio()
                throw error
            }
        }
    }

    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func observeAudioDisruption() {
        self.audioSessionObserving = []

        let interruptionBegan = NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .filter(self.isInterruptionBegan())
            .map { _ in () }

        let oldDeviceUnavailable = NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .filter(self.isOldDeviceUnavailable())
            .map { _ in () }

        let mediaServicesReset = NotificationCenter.default
            .publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .map { _ in () }

        Publishers.Merge3(interruptionBegan, oldDeviceUnavailable, mediaServicesReset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.subject.audioInputDisrupted.send(())
            }
            .store(in: &self.audioSessionObserving)
    }

    private func isInterruptionBegan() -> (Notification) -> Bool {
        return { notification in
            guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            else { return false }
            return AVAudioSession.InterruptionType(rawValue: raw) == .began
        }
    }

    private func isOldDeviceUnavailable() -> (Notification) -> Bool {
        return { notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            else { return false }
            return AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
        }
    }

    private func makeRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        return request
    }

    private func installInputTap() {
        let inputNode = self.audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.serialQueue.async {
                self?.request?.append(buffer)
                self?.updateVoiceLevel(buffer)
            }
        }
    }

    private func makeRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest
    ) -> SFSpeechRecognitionTask {
        return recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.serialQueue.async {
                self?.handleRecognition(result: result, error: error)
            }
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: (any Error)?) {
        if let result {
            let fragment = SpeechRecognizeFragment(
                text: result.bestTranscription.formattedString,
                isFinal: result.isFinal
            )
            self.subject.recognizedResult.send(.success(fragment))
        }
        if let error {
            self.subject.recognizedResult.send(.failure(error))
            self.teardownAudio()
        }
    }

    private func startEngine() throws {
        self.audioEngine.prepare()
        try self.audioEngine.start()
    }

    public func stop() {
        self.serialQueue.async {
            self.request?.endAudio()
            self.teardownAudio()
        }
    }

    // 무조건 호출해도 안전(idempotent): stop/cancel/removeTap 모두 미동작·미설치 상태에서 호출해도 무해.
    // start 실패 cleanup, 중복 stop, 에러 분기 self-teardown 모두 이 한 경로로 처리.
    private func teardownAudio() {
        self.audioSessionObserving = []
        self.task?.cancel()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.audioEngine = AVAudioEngine()
        self.request = nil
        self.task = nil
        self.subject.voiceLevel.send(0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func updateVoiceLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        let rms = sqrt(sumSquares / Float(frameLength))
        let dbfs = 20 * log10(max(rms, .leastNonzeroMagnitude))
        let level = max(0, min(1, (dbfs - self.noiseFloor) / -self.noiseFloor))
        self.subject.voiceLevel.send(level)
    }
}

extension SpeechRecognizeServiceImple {

    public var recognized: AnyPublisher<SpeechRecognizeFragment, any Error> {
        return self.subject.recognizedResult
            .setFailureType(to: (any Error).self)
            .tryMap { result in
                switch result {
                case .success(let fragment): return fragment
                case .failure(let error): throw error
                }
            }
            .eraseToAnyPublisher()
    }
    public var voiceLevel: AnyPublisher<Float, Never> {
        return self.subject.voiceLevel.eraseToAnyPublisher()
    }
    public var audioInputDisrupted: AnyPublisher<Void, Never> {
        return self.subject.audioInputDisrupted.eraseToAnyPublisher()
    }
}
