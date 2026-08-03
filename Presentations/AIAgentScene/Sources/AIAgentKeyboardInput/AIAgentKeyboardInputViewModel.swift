//
//  AIAgentKeyboardInputViewModel.swift
//  AIAgentScene
//

import Foundation
import Combine
import Domain


// MARK: - AIAgentKeyboardInputViewModel

protocol AIAgentKeyboardInputViewModel: AnyObject, Sendable {
    func prepare()
    func send(_ text: String)
    func stop()
    func close()
    func dismissByGesture()

    var usage: AnyPublisher<AIAgentUsage, Never> { get }
}


// MARK: - AIAgentKeyboardInputViewModelImple

final class AIAgentKeyboardInputViewModelImple: AIAgentKeyboardInputViewModel, @unchecked Sendable {

    private let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    var router: (any AIAgentKeyboardInputRouting)?

    init(aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase) {
        self.aiAgentOrchestrationUsecase = aiAgentOrchestrationUsecase
    }

    // 시트 진입 시 usage 최신화 — 갱신 트리거는 presentation 소유 (#713)
    func prepare() {
        self.aiAgentOrchestrationUsecase.loadUsage()
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


// MARK: - outputs

extension AIAgentKeyboardInputViewModelImple {

    var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.aiAgentOrchestrationUsecase.usage
    }
}
