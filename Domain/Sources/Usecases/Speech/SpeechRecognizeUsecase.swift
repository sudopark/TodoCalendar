//
//  SpeechRecognizeUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine


// MARK: - SpeechRecognizeUsecase

public protocol SpeechRecognizeUsecase: Sendable {

    func startListening()
    func stopListening()
    func finishListening()

    var recognizeResult: AnyPublisher<Result<String, any Error>, Never> { get }
    var recognizingText: AnyPublisher<String, Never> { get }
    var isRecognizingWithLevel: AnyPublisher<Float?, Never> { get }
}


// MARK: - SpeechRecognizeUsecaseImple

public final class SpeechRecognizeUsecaseImple: SpeechRecognizeUsecase, @unchecked Sendable {

    private let service: any SpeechRecognizeService
    private let permissionChecker: any SpeechRecognizePermissionChecker
    private let autoStopAfterSilence: TimeInterval

    public init(
        service: any SpeechRecognizeService,
        permissionChecker: any SpeechRecognizePermissionChecker,
        autoStopAfterSilence: TimeInterval = 3
    ) {
        self.service = service
        self.permissionChecker = permissionChecker
        self.autoStopAfterSilence = autoStopAfterSilence
    }

    private struct Subject {
        let isRecognizing = CurrentValueSubject<Bool, Never>(false)
        let result = PassthroughSubject<Result<String, any Error>, Never>()
        let recognizingText = CurrentValueSubject<String, Never>("")
    }
    private let subject = Subject()
    private var serviceBinding: AnyCancellable?
    private var textBinding: AnyCancellable?
}

extension SpeechRecognizeUsecaseImple {
    
    public func startListening() {
       
        guard !self.subject.isRecognizing.value else { return }
        
        Task {
            do {
                try await self.permissionChecker.requestAccess()
                self.bindService()
                try self.service.start()
                self.subject.isRecognizing.send(true)
                
            } catch {
                self.serviceBinding?.cancel()
                self.subject.isRecognizing.send(false)
                self.subject.result.send(.failure(error))
            }
        }
    }
    
    public func stopListening() {
        self.service.stop()
        self.serviceBinding?.cancel()
        self.textBinding?.cancel()
        self.subject.isRecognizing.send(false)
    }

    public func finishListening() {
        guard self.subject.isRecognizing.value else { return }
        let text = self.subject.recognizingText.value
        self.stopListening()
        self.subject.result.send(.success(text))
    }

    private func bindService() {

        let selectText: (SpeechRecognizeFragment?, Void?) -> RecognizeResult? = { fragment, timeout in

            switch (fragment, timeout) {
            case (.some(let frg), _) where frg.isFinal: return .recognized(frg.text)
            case (.some(let frg), .some): return .recognized(frg.text)
            case (.none, .some): return .timeout
            default: return nil
            }
        }

        self.subject.recognizingText.send("")

        self.serviceBinding?.cancel()
        self.serviceBinding = Publishers.CombineLatest(
            self.service.recognized.mapAsOptional().prepend(nil),
            self.silenceTimeout.mapAsAnyError().mapAsOptional().prepend(nil)
        )
        .compactMap(selectText)
        .first()
        .sink(
            receiveCompletion: self.handleCompletion(),
            receiveValue: self.handleRecognized()
        )

        self.textBinding?.cancel()
        self.textBinding = self.service.recognized
            .map { $0.text }
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] text in
                    self?.subject.recognizingText.send(text)
                }
            )
    }
    
    private enum RecognizeResult {
        case recognized(String)
        case timeout
    }
    
    private func handleCompletion() -> (Subscribers.Completion<any Error>) -> Void  {
        return  { [weak self] completion in
            guard let self, case .failure(let error) = completion
            else { return }
            
            self.stopListening()
            self.subject.result.send(.failure(error))
        }
    }
    
    private func handleRecognized() -> (RecognizeResult) -> Void {
        return { [weak self] result in
            self?.stopListening()
            guard case .recognized(let text) = result else { return }
            self?.subject.result.send(.success(text))
        }
    }
    
    private var silenceTimeout: AnyPublisher<Void, Never> {
        let interval = Int(self.autoStopAfterSilence * 1000)
        return self.service.voiceLevel
            .map { $0 == 0 }
            .removeDuplicates()
            .map { isSilence in
                guard isSilence
                else { return Empty<Void, Never>().eraseToAnyPublisher() }
                
                return  Just(()).delay(
                    for: .milliseconds(interval),
                    scheduler: DispatchQueue.main
                )
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}

extension SpeechRecognizeUsecaseImple {
    
    public var recognizeResult: AnyPublisher<Result<String, any Error>, Never> {
        return self.subject.result
            .eraseToAnyPublisher()
    }

    public var recognizingText: AnyPublisher<String, Never> {
        return self.subject.recognizingText
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var isRecognizingWithLevel: AnyPublisher<Float?, Never> {
        let service = self.service
        return self.subject.isRecognizing
            .map { flag in
                guard flag
                else {
                    return Just<Float?>(nil).eraseToAnyPublisher()
                }
                return service.voiceLevel
                    .mapAsOptional()
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}
