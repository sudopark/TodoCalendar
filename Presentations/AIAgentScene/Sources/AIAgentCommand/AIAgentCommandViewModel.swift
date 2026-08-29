//
//  AIAgentCommandViewModel.swift
//  AIAgentScene
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes


// MARK: - AIAgentCommandState

public enum AIAgentCommandState: Equatable, Sendable {
    case processing(command: String)
    case confirm(command: String, message: String?, expireTime: Date?)  // 만료 여부는 expireTime을 현재 시각과 비교해 소비자(뷰)가 파생
    case done(command: String, message: String?)
    case failed(command: String, reason: String?, errorCode: ServerErrorModel.ErrorCode?)
}


// MARK: - AIAgentCommandViewModel

public protocol AIAgentCommandViewModel: AnyObject, Sendable {

    func prepare()
    func sendCommand(_ text: String)
    func confirm()
    func decline()
    func cancel()
    func acknowledge()
    func close()
    func showPlans()
    func openNotificationSetting()

    var commandState: AnyPublisher<AIAgentCommandState?, Never> { get }
    var usage: AnyPublisher<AIAgentUsage, Never> { get }
    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> { get }
    var isNotificationPermissionDenied: AnyPublisher<Bool, Never> { get }
}


// MARK: - AIAgentCommandViewModelImple

final class AIAgentCommandViewModelImple: AIAgentCommandViewModel, @unchecked Sendable {

    private let orchestrationUsecase: any AIAgentOrchestrationUsecase
    private let billingUsecase: any BillingUsecase
    var router: (any AIAgentRouting)?
    weak var listener: (any AIAgentCommandSceneListener)?

    private let cancellables = CancelBag()

    init(
        orchestrationUsecase: any AIAgentOrchestrationUsecase,
        billingUsecase: any BillingUsecase
    ) {
        self.orchestrationUsecase = orchestrationUsecase
        self.billingUsecase = billingUsecase

        self.billingUsecase.currentUserPlan
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.orchestrationUsecase.loadUsage() }
            .store(in: self.cancellables)
    }
}


// MARK: - actions

extension AIAgentCommandViewModelImple {

    func prepare() {
        self.orchestrationUsecase.loadUsage()
        self.orchestrationUsecase.refreshNotificationPermissionStatus()
    }

    func sendCommand(_ text: String) {
        try? self.orchestrationUsecase.submit(text)
    }

    func confirm() {                       // 처리 계속 — 시트 유지
        self.orchestrationUsecase.confirm()
    }

    func decline() {                       // confirm 거부 → reject + idle
        self.orchestrationUsecase.decline()
        self.router?.closeScene()
    }

    func cancel() {                        // 진행 중 중지 → 확인 팝업. 확인 시에만 실제 중지
        let info = ConfirmDialogInfo()
            |> \.title .~ "aiAgent::stop::confirm::title".localized()
            |> \.message .~ "aiAgent::stop::confirm::message".localized()
            |> \.confirmText .~ "aiAgent::stop".localized()
            |> \.confirmed .~ { [weak self] in
                self?.orchestrationUsecase.reset()   // 서버 cancel API + idle, 재시작 불가
                self?.router?.closeScene()
            }
        self.router?.showConfirm(dialog: info)
    }

    func acknowledge() {                   // done/failed 확인 → reset(idle) + 닫기 (팝업 없음)
        self.orchestrationUsecase.reset()
        self.router?.closeScene()
    }

    func close() {                         // 숨김 — 상태 보존, 재진입 가능
        self.router?.closeScene()
    }

    func showPlans() {
        // reset 없이 idle로 안 돌아가면 다음 한도 초과 때 상위의 false→true 재전이 감지가 막혀 시트가 안 뜬다
        self.orchestrationUsecase.reset()
        self.listener?.aiAgentCommandDidRequestPaywall()
    }

    func openNotificationSetting() {
        self.router?.openSystemSetting()
    }
}


// MARK: - outputs

extension AIAgentCommandViewModelImple {

    var commandState: AnyPublisher<AIAgentCommandState?, Never> {
        return self.orchestrationUsecase.state
            .handleEvents(receiveOutput: { [weak self] state in
                // done/failed = 서버 크레딧 차감 완료 시점 → 게이지 최신화
                switch state {
                case .done, .failed:
                    self?.orchestrationUsecase.loadUsage()
                case .idle, .listening, .processing, .confirm:
                    break
                }
            })
            .map { state in
                switch state {
                case .idle:
                    return nil
                case .listening:
                    return nil
                case .processing(let command):
                    return .processing(command: command)
                case .confirm(let command, let message, _, let expireTime):
                    return .confirm(command: command, message: message, expireTime: expireTime)
                case .done(let command, let message):
                    return .done(command: command, message: message)
                case .failed(let command, let reason, let errorCode):
                    return .failed(command: command, reason: reason, errorCode: errorCode)
                }
            }
            .eraseToAnyPublisher()
    }

    var usage: AnyPublisher<AIAgentUsage, Never> {
        return self.orchestrationUsecase.usage
    }

    // seeding 전엔 currentUserPlan 이 무방출(.compactMap { $0 }) 이라 첫 값을 prepend 해
    // 뷰가 플랜 없는 상태부터 그릴 수 있게 한다. usage 와 CombineLatest 로 합성하지 않는다 —
    // 두 값은 독립 릴레이라 ViewState 가 각각 받으면 되고, 합성하면 한쪽이 안 오면 둘 다 막힌다 (#739)
    var currentUserPlan: AnyPublisher<BillingUserPlan?, Never> {
        return self.billingUsecase.currentUserPlan
            .map { $0 as BillingUserPlan? }
            .prepend(nil)
            .eraseToAnyPublisher()
    }

    var isNotificationPermissionDenied: AnyPublisher<Bool, Never> {
        return self.orchestrationUsecase.isNotificationPermissionDenied
    }
}
