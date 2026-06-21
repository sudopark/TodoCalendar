//
//  AIAgentCoordinatorViewModel.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - AIAgentCoordinatorViewModel

public protocol AIAgentCoordinatorViewModel: AnyObject, Sendable, AIAgentSceneInteractor {
    var listener: (any AIAgentSceneListener)? { get set }
}


// MARK: - AIAgentCoordinatorViewModelImple

public final class AIAgentCoordinatorViewModelImple: AIAgentCoordinatorViewModel, @unchecked Sendable {

    private let orchestrationUsecase: any AIAgentOrchestrationUsecase
    private let speechRecognizeUsecase: any SpeechRecognizeUsecase
    public weak var listener: (any AIAgentSceneListener)?
    var router: (any AIAgentRouting)?

    public init(
        orchestrationUsecase: any AIAgentOrchestrationUsecase,
        speechRecognizeUsecase: any SpeechRecognizeUsecase
    ) {
        self.orchestrationUsecase = orchestrationUsecase
        self.speechRecognizeUsecase = speechRecognizeUsecase
    }

    private enum InputMode {
        case idle
        case voice
        case keyboard
    }

    private var inputMode: InputMode = .idle
    private var latestState: AIAgentState?
    private var cancellables = Set<AnyCancellable>()
    private var isCommandSheetShown = false

    private lazy var inputViewModel: AIAgentInputViewModelImple = {
        let vm = AIAgentInputViewModelImple(speechRecognizeUsecase: self.speechRecognizeUsecase)
        vm.listener = self
        self.bindInputViewModel(vm)
        return vm
    }()

    private lazy var commandViewModel: AIAgentCommandViewModelImple = {
        let vm = AIAgentCommandViewModelImple(orchestrationUsecase: self.orchestrationUsecase)
        vm.listener = self
        return vm
    }()

    private func bindInputViewModel(_ vm: AIAgentInputViewModelImple) {
        vm.inputState
            .sink { [weak self] state in
                guard let self else { return }
                if state == .permissionDenied {
                    self.handlePermissionDenied()
                }
            }
            .store(in: &self.cancellables)

        vm.recognizingText
            .sink { [weak self] text in
                self?.listener?.aiAgent(didUpdateRecognizingText: text)
            }
            .store(in: &self.cancellables)

        vm.inputLevel
            .compactMap { $0 }
            .sink { [weak self] level in
                self?.listener?.aiAgent(didUpdateVoiceLevel: level)
            }
            .store(in: &self.cancellables)
    }
}


// MARK: - prepare

extension AIAgentCoordinatorViewModelImple {

    public func prepare() {
        self.orchestrationUsecase.state
            .sink(receiveValue: { [weak self] state in
                self?.latestState = state
                self?.resolveAndNotifyMode()
                self?.handleCommandSheet(for: state)
            })
            .store(in: &self.cancellables)
        self.orchestrationUsecase.restoreIfNeeded()
        self.orchestrationUsecase.loadUsage()
    }

    private func handleCommandSheet(for state: AIAgentState) {
        switch state {
        case .processing, .confirm, .done, .failed:
            guard !isCommandSheetShown else { return }
            router?.showCommandSheet(commandViewModel)
            isCommandSheetShown = true
        case .idle:
            guard isCommandSheetShown else { return }
            router?.dismissCommandSheet()
            isCommandSheetShown = false
        }
    }

    private func handlePermissionDenied() {
        self.listener?.aiAgentDidRequestKeyboardEntryAvailable()
        self.inputMode = .keyboard
        self.resolveAndNotifyMode()
    }

    private func resolveAndNotifyMode() {
        let mode: AIAgentEntryMode
        switch latestState {
        case .processing:
            mode = .command(.processing)
        case .confirm:
            mode = .command(.needConfirm)
        case .done:
            mode = .command(.done)
        case .failed:
            mode = .command(.failed)
        case .idle, .none:
            switch inputMode {
            case .voice:
                mode = .voice
            case .keyboard:
                mode = .keyboard
            case .idle:
                mode = latestState == nil ? .none : .idle
            }
        }
        self.listener?.aiAgent(didChangeMode: mode)
    }
}


// MARK: - AIAgentSceneInteractor

extension AIAgentCoordinatorViewModelImple {

    public func enterVoiceInput() {
        self.inputMode = .voice
        self.inputViewModel.startInput()
        self.resolveAndNotifyMode()
    }

    public func enterKeyboardInput() {
        self.inputMode = .keyboard
        self.inputViewModel.switchToKeyboard()
        self.resolveAndNotifyMode()
    }

    public func stopInput() {
        self.inputMode = .idle
        self.inputViewModel.stopInput()
        self.resolveAndNotifyMode()
    }

    public func submit(_ text: String) {
        self.orchestrationUsecase.sendCommand(text)
    }
}


// MARK: - AIAgentCommandViewModelListener

extension AIAgentCoordinatorViewModelImple: AIAgentCommandViewModelListener {

    func aiAgentCommandRequestClose() {
        self.orchestrationUsecase.reset()
    }
}


// MARK: - AIAgentInputViewModelListener

extension AIAgentCoordinatorViewModelImple: AIAgentInputViewModelListener {

    func aiAgentInput(didComplete text: String) {
        self.inputMode = .idle
        self.submit(text)
    }

    func aiAgentInputRequestSystemSetting() {
        self.router?.openSystemSetting()
    }

    func aiAgentInput(didFail error: any Error) {
        self.inputMode = .idle
        self.resolveAndNotifyMode()
    }
}
