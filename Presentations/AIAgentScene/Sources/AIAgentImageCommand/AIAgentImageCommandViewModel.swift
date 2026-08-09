//
//  AIAgentImageCommandViewModel.swift
//  AIAgentScene
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions


// MARK: - AIAgentImageCommandStage

enum AIAgentImageCommandStage: Equatable {
    case recognizing
    case editing(text: String)
    case noTextFound
}


// MARK: - AIAgentImageCommandViewModel

protocol AIAgentImageCommandViewModel: AnyObject, Sendable {
    func prepare()
    func send(text: String, additionalInstruction: String)
    func close()
    func dismissByGesture()

    var stage: AnyPublisher<AIAgentImageCommandStage, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }
    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> { get }
}


// MARK: - AIAgentImageCommandViewModelImple

final class AIAgentImageCommandViewModelImple: AIAgentImageCommandViewModel, @unchecked Sendable {

    private let imageData: Data
    private let imageTextRecognizeService: any ImageTextRecognizeService
    private let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    private let billingUsecase: any BillingUsecase
    var router: (any AIAgentImageCommandRouting)?

    init(
        imageData: Data,
        imageTextRecognizeService: any ImageTextRecognizeService,
        aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase,
        billingUsecase: any BillingUsecase
    ) {
        self.imageData = imageData
        self.imageTextRecognizeService = imageTextRecognizeService
        self.aiAgentOrchestrationUsecase = aiAgentOrchestrationUsecase
        self.billingUsecase = billingUsecase
    }

    deinit {
        self.recognizeTask?.cancel()
    }

    private struct Subject {
        let stage = CurrentValueSubject<AIAgentImageCommandStage, Never>(.recognizing)
    }
    private let subject = Subject()
    private var recognizeTask: Task<Void, Never>?
}


// MARK: - 인식

extension AIAgentImageCommandViewModelImple {

    func prepare() {
        self.aiAgentOrchestrationUsecase.loadUsage()
        self.startRecognize()
    }

    private func startRecognize() {
        self.recognizeTask?.cancel()
        self.subject.stage.send(.recognizing)

        self.recognizeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let lines = try await self.imageTextRecognizeService
                    .recognizeTextLines(in: self.imageData)
                self.handleRecognized(lines)
            } catch is CancellationError {
                // 닫기로 인한 취소 — 화면이 이미 사라졌으므로 알리지 않는다
            } catch {
                // 디코드·Vision 실패도 noTextFound로 수렴 — 유저 다음 행동(다른 이미지 선택)이 동일하고,
                // 닫히는 중인 시트에서 알림을 띄우면 dismiss가 알림 자신을 닫아 시트가 갇는다.
                // UI가 빈 결과와 실패를 의도적으로 구분하지 않으므로 원인 추적은 로그로 남긴다
                logger.log(level: .error, "\(error)")
                self.subject.stage.send(.noTextFound)
            }
        }
    }

    private func handleRecognized(_ lines: [String]) {
        guard !lines.isEmpty else {
            self.subject.stage.send(.noTextFound)
            return
        }
        self.subject.stage.send(.editing(text: lines.joined(separator: "\n")))
    }
}


// MARK: - 제출·닫기

extension AIAgentImageCommandViewModelImple {

    func send(text: String, additionalInstruction: String) {
        do {
            try self.aiAgentOrchestrationUsecase.submitImageCommand(
                text: text, additionalInstruction: additionalInstruction
            )
            self.router?.closeScene()
        } catch let reason as AIImageCommandSubmitFailReason {
            self.router?.showToast(reason.message)
        } catch {
            self.router?.showError(error)
        }
    }

    // 시트만 닫음 — 음성 입력 복귀는 View의 onDisappear(dismissByGesture)가 처리 (키보드 입력 시트와 동일)
    func close() {
        self.recognizeTask?.cancel()
        self.recognizeTask = nil
        self.router?.closeScene()
    }

    func dismissByGesture() {
        self.recognizeTask?.cancel()
        self.recognizeTask = nil
        self.aiAgentOrchestrationUsecase.enterVoiceInput()
    }
}


// MARK: - outputs

extension AIAgentImageCommandViewModelImple {

    var stage: AnyPublisher<AIAgentImageCommandStage, Never> {
        return self.subject.stage.removeDuplicates().eraseToAnyPublisher()
    }

    var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.aiAgentOrchestrationUsecase.usage
    }

    // 키보드 입력 시트와 동일 — seeding 전 무방출이라 첫 값을 prepend 해 플랜 없는 상태부터 그린다 (#739)
    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> {
        return self.billingUsecase.currentUserPlan
            .map { $0 as BillingUserPlan? }
            .prepend(nil)
            .eraseToAnyPublisher()
    }
}


private extension AIImageCommandSubmitFailReason {

    var message: String {
        switch self {
        case .emptyText: return "aiAgent::image::empty".localized()
        case .textTooLong: return "aiAgent::image::textTooLong".localized()
        case .instructionTooLong: return "aiAgent::image::instructionTooLong".localized()
        case .busy: return "aiAgent::image::busy".localized()
        }
    }
}
