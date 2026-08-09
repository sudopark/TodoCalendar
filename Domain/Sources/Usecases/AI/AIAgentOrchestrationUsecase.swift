//
//  AIAgentOrchestrationUsecase.swift
//  Domain
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - AIAgentOrchestrationUsecase

public protocol AIAgentOrchestrationUsecase: AnyObject, Sendable {

    var state: AnyPublisher<AIAgentState, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }
    var recognizingText: AnyPublisher<String, Never> { get }
    var voiceLevel: AnyPublisher<Float, Never> { get }
    var speechPermissionDenied: AnyPublisher<Void, Never> { get }

    func prepare()
    func enterVoiceInput()
    func finishVoiceInput()
    func enterKeyboardInput()
    func enterImageInput()
    func stopInput()
    func submit(_ text: String) throws
    func submitImageCommand(text: String, additionalInstruction: String?) throws

    func confirm()
    func decline()

    func reset()
    func restoreIfNeeded()
    func loadUsage()

    func handleJobStatusChanged(_ jobId: String)
    func refreshProcessingJobIfNeeded()

    func handleSignedOut() async
}


// MARK: - AIAgentOrchestrationUsecaseImple

public final class AIAgentOrchestrationUsecaseImple: AIAgentOrchestrationUsecase, @unchecked Sendable {

    private let commandUsecase: any AICommandUsecase
    private let usageUsecase: any AIAgentUsageUsecase
    private let speechRecognizeUsecase: any SpeechRecognizeUsecase
    private let eventSyncUsecase: any EventSyncUsecase

    public init(
        commandUsecase: any AICommandUsecase,
        usageUsecase: any AIAgentUsageUsecase,
        speechRecognizeUsecase: any SpeechRecognizeUsecase,
        eventSyncUsecase: any EventSyncUsecase
    ) {
        self.commandUsecase = commandUsecase
        self.usageUsecase = usageUsecase
        self.speechRecognizeUsecase = speechRecognizeUsecase
        self.eventSyncUsecase = eventSyncUsecase
    }

    private struct Subject {
        let state = CurrentValueSubject<AIAgentState?, Never>(nil)
        let recognizingText = PassthroughSubject<String, Never>()
        let voiceLevel = PassthroughSubject<Float, Never>()
        let speechPermissionDenied = PassthroughSubject<Void, Never>()
    }
    private let subject = Subject()
    private var commandCancellable: AnyCancellable?
    private var voiceInputBindings = Set<AnyCancellable>()
    private var currentProcessingJobId: String?

    private func startProcessing(_ processing: AnyPublisher<AICommandProcessing, any Error>) {
        self.commandCancellable?.cancel()
        self.commandCancellable = processing
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.currentProcessingJobId = nil
                        self?.subject.state.send(.failed(command: self?.currentCommand ?? "", reason: nil, errorCode: nil))
                    }
                },
                receiveValue: { [weak self] processing in
                    self?.currentProcessingJobId = processing.jobId
                    guard case .job(let job) = processing else { return }
                    self?.handleJobResult(job)
                }
            )
    }

    private func handleJobResult(_ job: AIJob) {
        guard job.isFinish else { return }
        if job.status != .confirm {
            self.currentProcessingJobId = nil
        }
        self.triggerEventSyncIfNeeded(job.result)
        if job.status == .rejected || job.status == .canceled {
            self.subject.state.send(.idle)
            return
        }
        guard let result = job.result else { return }
        switch result {
        case .done(let done):
            self.subject.state.send(.done(command: job.command ?? "", message: done.text))
        case .confirm(let confirm):
            guard let action = confirm.action else {
                self.subject.state.send(.failed(command: job.command ?? "", reason: confirm.text, errorCode: nil))
                return
            }
            // 과거 exp도 그대로 방출 — 만료 여부는 소비자가 expireTime을 현재 시각과 비교해 파생한다.
            self.subject.state.send(
                .confirm(
                    command: job.command ?? "", message: confirm.text,
                    action: action, expireTime: action.tokenExpireTime
                )
            )
        case .failed(let fail):
            self.subject.state.send(.failed(command: job.command ?? "", reason: fail.reason, errorCode: fail.errorCode))
        case .canceled:
            self.subject.state.send(.idle)
        }
    }

    private func triggerEventSyncIfNeeded(_ result: AIJobResult?) {
        guard let result,
              result.mutations.contains(where: { $0.dataType.requiresEventSync })
        else { return }
        self.eventSyncUsecase.sync()
    }
}


// MARK: - prepare

extension AIAgentOrchestrationUsecaseImple {

    public func prepare() {
        self.restoreIfNeeded()
        self.loadUsage()
    }
}


// MARK: - 입력 제어

extension AIAgentOrchestrationUsecaseImple {

    public func enterVoiceInput() {
        guard self.canEnterVoiceInput else { return }
        self.bindSpeechRecognizing()
        self.speechRecognizeUsecase.startListening()
        self.subject.state.send(.listening(.voice))
    }

    public func finishVoiceInput() {
        self.subject.state.send(.idle)
        self.speechRecognizeUsecase.finishListening()
    }

    public func enterKeyboardInput() {
        guard self.canEnterKeyboardInput else { return }
        self.resetVoiceBinding()
        self.speechRecognizeUsecase.stopListening()
        self.subject.state.send(.listening(.keyboard))
    }

    public func enterImageInput() {
        guard self.canEnterImageInput else { return }
        self.speechRecognizeUsecase.stopListening()
        self.subject.state.send(.listening(.image))
    }

    public func stopInput() {
        self.resetVoiceBinding()
        self.speechRecognizeUsecase.stopListening()
        self.subject.state.send(.idle)
    }

    private func bindSpeechRecognizing() {
        self.resetVoiceBinding()

        self.speechRecognizeUsecase.recognizeResult
            .sink { [weak self] result in
                self?.handleRecognizeEnd(result)
            }
            .store(in: &self.voiceInputBindings)

        self.speechRecognizeUsecase.recognizingText
            .sink { [weak self] text in
                self?.subject.recognizingText.send(text)
            }
            .store(in: &self.voiceInputBindings)

        self.speechRecognizeUsecase.isRecognizingWithLevel
            .compactMap { $0 }
            .sink { [weak self] level in
                self?.subject.voiceLevel.send(level)
            }
            .store(in: &self.voiceInputBindings)
    }

    // 인식 종료는 텍스트 확보·무인식·실패를 가리지 않고 stopInput과 동등하게 접는다.
    // 바인딩을 남기면 다음 입력 세션에 이전 구독이 겹친다.
    private func handleRecognizeEnd(_ result: Result<SpeechRecognizeResult, any Error>) {
        self.resetVoiceBinding()
        self.subject.state.send(.idle)
        switch result {
        case .success(.recognized(let text)):
            try? self.submit(text)
        case .failure(let error):
            self.notifyIfPermissionDenied(error)
        default:
            break
        }
    }

    private func notifyIfPermissionDenied(_ error: any Error) {
        guard let authError = error as? SpeechRecognizeAuthError, authError.isDenied
        else { return }
        self.subject.speechPermissionDenied.send(())
    }

    private func resetVoiceBinding() {
        self.voiceInputBindings.forEach { $0.cancel() }
        self.voiceInputBindings.removeAll()
    }
}


// MARK: - submit / command actions

extension AIAgentOrchestrationUsecaseImple {

    private enum Constant {
        static let maxTextLength: Int = 10000
        static let maxAdditionalInstructionLength: Int = 1000
    }

    public func submit(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RuntimeError(key: "AIAgent.emptyCommand", "command text is empty")
        }
        guard self.canSubmit else {
            throw RuntimeError(key: "AIAgent.busy", "already processing a command")
        }
        self.subject.state.send(.processing(command: trimmed))
        self.startProcessing(self.commandUsecase.processCommand(trimmed))
    }

    public func submitImageCommand(text: String, additionalInstruction: String?) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty
        else { throw AIImageCommandSubmitFailReason.emptyText }
        guard trimmed.count <= Constant.maxTextLength
        else { throw AIImageCommandSubmitFailReason.textTooLong }

        let trimmedInstruction = additionalInstruction?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction: String? = (trimmedInstruction?.isEmpty ?? true) ? nil : trimmedInstruction
        guard (instruction?.count ?? 0) <= Constant.maxAdditionalInstructionLength
        else { throw AIImageCommandSubmitFailReason.instructionTooLong }

        guard self.canSubmit
        else { throw AIImageCommandSubmitFailReason.busy }

        self.subject.state.send(.processing(command: trimmed))
        self.startProcessing(
            self.commandUsecase.processInterpretCommand(
                text: trimmed,
                additionalInstruction: instruction,
                inputSource: .imageOcr
            )
        )
    }

    private var canEnterKeyboardInput: Bool {
        switch self.subject.state.value {
        case .none, .idle, .listening: return true
        default: return false
        }
    }

    private var canSubmit: Bool {
        switch self.subject.state.value {
        case .none, .idle, .listening: return true
        default: return false
        }
    }

    // 현재 진행 중인 command (실패 상태에 원본 지시를 실어주기 위함)
    private var currentCommand: String {
        switch self.subject.state.value {
        case .processing(let command): return command
        case .confirm(let command, _, _, _): return command
        default: return ""
        }
    }

    private var canEnterVoiceInput: Bool {
        switch self.subject.state.value {
        case .none, .idle, .listening(.keyboard), .listening(.image): return true
        default: return false
        }
    }

    private var canEnterImageInput: Bool {
        switch self.subject.state.value {
        case .none, .idle, .listening: return true
        default: return false
        }
    }

    public func confirm() {
        guard case .confirm(let command, _, let action, let expireTime) = self.subject.state.value ?? .idle
        else { return }
        // expireTime nil(만료 시각 불명)이면 만료 검증 없이 그대로 진행. 과거면 차단만 — 상태 전이는 없다.
        if let expireTime, expireTime <= Date() { return }
        self.subject.state.send(.processing(command: command))
        self.startProcessing(self.commandUsecase.processConfirmCommand(action))
    }

    public func decline() {
        switch self.subject.state.value ?? .idle {
        case .confirm(_, _, let action, _):
            self.commandUsecase.rejectConfirmCommand(action)
        default:
            break
        }
        self.stopTrackingJob()
        self.subject.state.send(.idle)
    }

    public func reset() {
        let jobId = self.currentProcessingJobId
        self.stopTrackingJob()
        if let jobId {
            self.commandUsecase.cancelOngoingCommand(jobId)
        }
        self.subject.state.send(.idle)
    }

    private func stopTrackingJob() {
        self.commandCancellable?.cancel()
        self.commandCancellable = nil
        self.currentProcessingJobId = nil
    }

    public func handleSignedOut() async {
        self.stopTrackingJob()
        self.resetVoiceBinding()
        self.speechRecognizeUsecase.stopListening()
        await self.commandUsecase.clearProcessingCommandRecord()
        self.subject.state.send(.idle)
    }

    public func restoreIfNeeded() {
        self.commandCancellable?.cancel()
        self.commandCancellable = self.commandUsecase.restoreCommandifNeed()
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.subject.state.send(.idle)
                    }
                },
                receiveValue: { [weak self] processing in
                    guard let self else { return }
                    guard let processing else {
                        self.subject.state.send(.idle)
                        return
                    }
                    self.currentProcessingJobId = processing.jobId
                    guard case .job(let job) = processing else { return }
                    // 앱 밖에서 만들어진 job은 복원 시점에 아직 진행 중이다.
                    // handleJobResult는 종료 job만 다루므로 여기서 processing으로 올려야
                    // 진행 상태가 보이고 canSubmit 가드도 이 job을 인지한다.
                    guard job.isFinish else {
                        self.subject.state.send(.processing(command: job.command ?? ""))
                        return
                    }
                    self.handleJobResult(job)
                }
            )
    }

    public func loadUsage() {
        self.usageUsecase.refresh()
    }

    public func handleJobStatusChanged(_ jobId: String) {
        guard self.currentProcessingJobId == jobId else {
            self.restoreIfNeededWhenIdle()
            return
        }
        // 만료된 confirm job은 더 조회하지 않는다 — 로컬 종료(추적 해제)로 push 즉시 조회 대상에서 뺀다.
        if case .confirm(_, _, _, let expireTime) = self.subject.state.value ?? .idle,
           let expireTime, expireTime <= Date() {
            self.currentProcessingJobId = nil
            return
        }
        self.commandUsecase.refreshJobStatus(jobId)
    }

    private func restoreIfNeededWhenIdle() {
        switch self.subject.state.value {
        case .idle:
            self.restoreIfNeeded()
        default:
            break
        }
    }

    public func refreshProcessingJobIfNeeded() {
        switch self.subject.state.value {
        case .processing:
            guard let jobId = self.currentProcessingJobId else { return }
            self.commandUsecase.refreshJobStatus(jobId)

        case .idle:
            // 앱이 노는 동안 확장·인텐트가 만든 job은 앱 메모리에 없다 — DB에서 이어받는다.
            // 그래야 결과를 보여주고, canSubmit 가드도 그 job을 인지해 덮어쓰기를 막는다.
            self.restoreIfNeeded()

        default:
            // 미방출(prepare의 복원 진행 중)·입력 중·결과 표시 중이면 화면 상태를 덮지 않는다
            break
        }
    }
}


// MARK: - outputs

extension AIAgentOrchestrationUsecaseImple {

    public var state: AnyPublisher<AIAgentState, Never> {
        return self.subject.state.compactMap { $0 }.eraseToAnyPublisher()
    }

    public var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.usageUsecase.currentUsage
    }

    public var recognizingText: AnyPublisher<String, Never> {
        return self.subject.recognizingText.eraseToAnyPublisher()
    }

    public var voiceLevel: AnyPublisher<Float, Never> {
        return self.subject.voiceLevel.eraseToAnyPublisher()
    }

    public var speechPermissionDenied: AnyPublisher<Void, Never> {
        return self.subject.speechPermissionDenied.eraseToAnyPublisher()
    }
}


// MARK: - NotNeedAIAgentOrchestrationUsecase

public final class NotNeedAIAgentOrchestrationUsecase: AIAgentOrchestrationUsecase, Sendable {

    public init() { }

    public var state: AnyPublisher<AIAgentState, Never> {
        return Just(.idle).eraseToAnyPublisher()
    }

    public var usage: AnyPublisher<AIAgentUsage, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    public var recognizingText: AnyPublisher<String, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    public var voiceLevel: AnyPublisher<Float, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    public var speechPermissionDenied: AnyPublisher<Void, Never> {
        return Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    public func prepare() { }
    public func enterVoiceInput() { }
    public func finishVoiceInput() { }
    public func enterKeyboardInput() { }
    public func enterImageInput() { }
    public func stopInput() { }

    public func submit(_ text: String) throws {
        throw RuntimeError(key: "AIAgent.needSignIn", "ai agent needs sign in")
    }

    public func submitImageCommand(text: String, additionalInstruction: String?) throws {
        throw RuntimeError(key: "AIAgent.needSignIn", "ai agent needs sign in")
    }

    public func confirm() { }
    public func decline() { }
    public func reset() { }
    public func restoreIfNeeded() { }
    public func loadUsage() { }
    public func handleJobStatusChanged(_ jobId: String) { }
    public func refreshProcessingJobIfNeeded() { }
    public func handleSignedOut() async { }
}
