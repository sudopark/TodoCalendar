//
//  AIAgentKeyboardInputViewModel.swift
//  AIAgentScene
//

import Foundation
import Combine
import Domain


// MARK: - AIAgentKeyboardInputViewModel

protocol AIAgentKeyboardInputViewModel: AnyObject, Sendable {
    func send(_ text: String)
    func stop()
    func close()
    func dismissByGesture()
}


// MARK: - AIAgentKeyboardInputViewModelImple

final class AIAgentKeyboardInputViewModelImple: AIAgentKeyboardInputViewModel, @unchecked Sendable {

    private let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    var router: (any AIAgentKeyboardInputRouting)?

    init(aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase) {
        self.aiAgentOrchestrationUsecase = aiAgentOrchestrationUsecase
    }

    func send(_ text: String) {
        do {
            try self.aiAgentOrchestrationUsecase.submit(text)
            self.router?.closeScene()
        } catch {
            self.router?.showError(error)
        }
    }

    func stop() {
        self.aiAgentOrchestrationUsecase.stopInput()
        self.router?.closeScene()
    }

    // 시트만 닫음 — 음성 입력 복귀는 View의 onDisappear(dismissByGesture)가 처리
    func close() {
        self.router?.closeScene()
    }

    func dismissByGesture() {
        self.aiAgentOrchestrationUsecase.enterVoiceInput()
    }
}
