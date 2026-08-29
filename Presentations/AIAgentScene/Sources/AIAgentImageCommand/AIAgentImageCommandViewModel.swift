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
    func openNotificationSetting()

    var stage: AnyPublisher<AIAgentImageCommandStage, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }
    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> { get }
    var isNotificationPermissionDenied: AnyPublisher<Bool, Never> { get }
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
        self.aiAgentOrchestrationUsecase.refreshNotificationPermissionStatus()
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

    func openNotificationSetting() {
        self.router?.openSystemSetting()
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

    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> {
        return self.billingUsecase.currentUserPlan
            .map { $0 as BillingUserPlan? }
            .prepend(nil)
            .eraseToAnyPublisher()
    }

    var isNotificationPermissionDenied: AnyPublisher<Bool, Never> {
        return self.aiAgentOrchestrationUsecase.isNotificationPermissionDenied
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
