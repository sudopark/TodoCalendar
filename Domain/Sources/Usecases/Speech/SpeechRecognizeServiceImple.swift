//
//  SpeechRecognizeServiceImple.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Speech
import AVFoundation


public final class SpeechRecognizeServiceImple: SpeechRecognizeService, @unchecked Sendable {

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private let recognizedSubject = PassthroughSubject<SpeechRecognizeFragment, any Error>()
    private let voiceActiveSubject = CurrentValueSubject<Bool, Never>(false)

    // 입력 레벨이 이 dBFS 이상이면 발화 중으로 간주
    private let voiceActivityThreshold: Float = -35.0

    public init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    public var recognized: AnyPublisher<SpeechRecognizeFragment, any Error> {
        return self.recognizedSubject.eraseToAnyPublisher()
    }
    public var isVoiceActive: AnyPublisher<Bool, Never> {
        return self.voiceActiveSubject.removeDuplicates().eraseToAnyPublisher()
    }

    public func start() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognizeFailReason.recognizerUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = self.audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
            self?.updateVoiceActivity(buffer)
        }

        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let fragment = SpeechRecognizeFragment(
                    text: result.bestTranscription.formattedString,
                    isFinal: result.isFinal
                )
                self.recognizedSubject.send(fragment)
            }
            if let error {
                self.recognizedSubject.send(completion: .failure(error))
                self.teardownAudio()
            }
        }

        self.audioEngine.prepare()
        try self.audioEngine.start()
    }

    public func stop() {
        self.request?.endAudio()
        self.task?.cancel()
        self.teardownAudio()
    }

    private func teardownAudio() {
        if self.audioEngine.isRunning {
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
        }
        self.request = nil
        self.task = nil
        self.voiceActiveSubject.send(false)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func updateVoiceActivity(_ buffer: AVAudioPCMBuffer) {
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
        self.voiceActiveSubject.send(dbfs >= self.voiceActivityThreshold)
    }
}
