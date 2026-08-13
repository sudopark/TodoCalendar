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
    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> { get }
}


// MARK: - AIAgentKeyboardInputViewModelImple

final class AIAgentKeyboardInputViewModelImple: AIAgentKeyboardInputViewModel, @unchecked Sendable {

    private let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    private let billingUsecase: any BillingUsecase
    var router: (any AIAgentKeyboardInputRouting)?

    init(
        aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase,
        billingUsecase: any BillingUsecase
    ) {
        self.aiAgentOrchestrationUsecase = aiAgentOrchestrationUsecase
        self.billingUsecase = billingUsecase
    }

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
        try? self.aiAgentOrchestrationUsecase.enterVoiceInput()
    }
}


// MARK: - outputs

extension AIAgentKeyboardInputViewModelImple {

    var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.aiAgentOrchestrationUsecase.usage
    }

    // seeding 전엔 currentUserPlan 이 무방출(.compactMap { $0 }) 이라 첫 값을 prepend 해
    // 뷰가 플랜 없는 상태부터 그릴 수 있게 한다. usage 와 CombineLatest 로 합성하지 않는다 (#739)
    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> {
        return self.billingUsecase.currentUserPlan
            .map { $0 as BillingUserPlan? }
            .prepend(nil)
            .eraseToAnyPublisher()
    }
}
