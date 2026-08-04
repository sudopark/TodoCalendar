//
//  AIAgentCommandViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 6/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit

@testable import AIAgentScene


class AIAgentCommandViewModelImpleTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!
    private var stubAgent: StubAIAgentOrchestrationUsecase!
    private var spyRouter: SpyAIAgentRouter!

    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubAgent = .init()
        self.spyRouter = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubAgent = nil
        self.spyRouter = nil
        FeatureFlag.disable(.billingPaywall)
    }

    private func makeViewModel(userPlan: BillingUserPlan? = nil) -> AIAgentCommandViewModelImple {
        let viewModel = AIAgentCommandViewModelImple(
            orchestrationUsecase: self.stubAgent,
            billingUsecase: StubBillingUsecase(stubUserPlan: userPlan)
        )
        viewModel.router = self.spyRouter
        return viewModel
    }

    private func observeCommand(_ viewModel: any AIAgentCommandViewModel) -> () -> AIAgentCommandState?? {
        var last: AIAgentCommandState??
        viewModel.commandState
            .sink(receiveValue: { last = $0 })
            .store(in: &self.cancelBag)
        return { last }
    }
}


// MARK: - 시트 액션과 orchestration 위임

extension AIAgentCommandViewModelImpleTests {

    func test_sendCommand_delegatesToUsecase() {
        let viewModel = self.makeViewModel()
        viewModel.sendCommand("회의")
        XCTAssertEqual(self.stubAgent.didSubmit, "회의")
    }

    func test_confirm_delegatesAndKeepsSceneOpen() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.confirm()
        // then
        XCTAssertEqual(self.stubAgent.didConfirm, true)
        XCTAssertNil(self.spyRouter.didClosed)   // confirm은 시트 유지(처리 계속)
    }

    func test_decline_declinesAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.decline()
        // then
        XCTAssertEqual(self.stubAgent.didDecline, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }

    func test_cancel_showsStopConfirmDialog() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.cancel()
        // then — 즉시 중지하지 않고 확인 팝업부터 노출
        XCTAssertNotNil(self.spyRouter.didShowConfirmWith)
    }

    func test_cancel_whenConfirmed_resetsAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        self.spyRouter.shouldConfirmNotCancel = true   // 팝업에서 '중지' 선택
        // when
        viewModel.cancel()
        // then
        XCTAssertEqual(self.stubAgent.didReset, true)   // reset → 서버 cancel API
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }

    func test_cancel_whenDialogDismissed_doesNotResetNorClose() {
        // given
        let viewModel = self.makeViewModel()
        self.spyRouter.shouldConfirmNotCancel = false   // 팝업에서 '취소' 선택
        // when
        viewModel.cancel()
        // then — 확인 안 하면 중지 안 되고 시트도 유지
        XCTAssertFalse(self.stubAgent.didReset)
        XCTAssertNil(self.spyRouter.didClosed)
    }

    func test_acknowledge_resetsAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.acknowledge()
        // then — 팝업 없이 바로 reset(idle) + 닫기
        XCTAssertEqual(self.stubAgent.didReset, true)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }

    func test_close_keepsStateAndClosesScene() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.close()
        // then — 상태 보존(orchestration 안 건드림), 시트만 닫음
        XCTAssertFalse(self.stubAgent.didReset)
        XCTAssertFalse(self.stubAgent.didDecline)
        XCTAssertEqual(self.spyRouter.didClosed, true)
    }
}


// MARK: - commandState 매핑

extension AIAgentCommandViewModelImpleTests {

    func test_whenOrchestratorIdle_commandStateIsNil() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        self.stubAgent.stateSubject.send(.idle)
        XCTAssertEqual(command(), .some(.none))
    }

    func test_whenOrchestratorProcessing_commandStateIsProcessing() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        self.stubAgent.stateSubject.send(.processing(command: "회의"))
        XCTAssertEqual(command(), .processing(command: "회의"))
    }

    func test_whenOrchestratorConfirm_commandStateCarriesMessage() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        let expireTime = Date().addingTimeInterval(300)
        self.stubAgent.stateSubject.send(
            .confirm(command: "삭제", message: "정말?", action: AIConfirmCommandAction(), expireTime: expireTime)
        )
        XCTAssertEqual(command(), .confirm(command: "삭제", message: "정말?", expireTime: expireTime))
    }

    func test_whenOrchestratorDone_commandStateIsDone() {
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        self.stubAgent.stateSubject.send(.done(command: "회의 추가", message: "완료"))
        XCTAssertEqual(command(), .done(command: "회의 추가", message: "완료"))
    }

    func test_whenOrchestratorFailed_commandStateCarriesErrorCode() {
        // given
        let viewModel = self.makeViewModel()
        let command = self.observeCommand(viewModel)
        // when
        self.stubAgent.stateSubject.send(
            .failed(command: "회의", reason: "오늘 사용량을 모두 썼어요", errorCode: .dailyLimitExceeded)
        )
        // then
        XCTAssertEqual(command(), .failed(command: "회의", reason: "오늘 사용량을 모두 썼어요", errorCode: .dailyLimitExceeded))
    }

    func test_beforeOrchestratorDetermined_emitsNothing() {
        let viewModel = self.makeViewModel()
        var emitted: [AIAgentCommandState?] = []
        viewModel.commandState
            .sink(receiveValue: { emitted.append($0) })
            .store(in: &self.cancelBag)
        XCTAssertTrue(emitted.isEmpty)
    }
}


// MARK: - usage 노출·갱신

extension AIAgentCommandViewModelImpleTests {

    func test_prepare_refreshUsage() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.prepare()
        // then
        XCTAssertEqual(self.stubAgent.didLoadUsage, true)
    }

    func test_usage_emitsCurrentUsage() {
        // given
        let viewModel = self.makeViewModel()
        self.stubAgent.usageSubject.send(.init(input: 100, output: 200, limit: 5000))
        var usage: AIAgentUsage?
        // when
        viewModel.usage
            .sink(receiveValue: { usage = $0 })
            .store(in: &self.cancelBag)
        // then — CurrentValueSubject replay라 동기 방출
        XCTAssertEqual(usage?.inputTokens, 100)
        XCTAssertEqual(usage?.outputTokens, 200)
        XCTAssertEqual(usage?.dailyLimit, 5000)
    }

    // done/failed = 서버 크레딧 차감이 끝난 시점 → usage 재갱신
    func test_commandState_whenDone_refreshUsage() {
        // given
        let viewModel = self.makeViewModel()
        let observe = self.observeCommand(viewModel)
        // when
        self.stubAgent.stateSubject.send(.done(command: "회의", message: nil))
        // then
        XCTAssertEqual(self.stubAgent.didLoadUsage, true)
        _ = observe
    }

    func test_commandState_whenFailed_refreshUsage() {
        // given
        let viewModel = self.makeViewModel()
        let observe = self.observeCommand(viewModel)
        // when
        self.stubAgent.stateSubject.send(.failed(command: "회의", reason: nil, errorCode: nil))
        // then
        XCTAssertEqual(self.stubAgent.didLoadUsage, true)
        _ = observe
    }

    func test_commandState_whenProcessing_notRefreshUsage() {
        // given
        let viewModel = self.makeViewModel()
        let observe = self.observeCommand(viewModel)
        // when
        self.stubAgent.stateSubject.send(.processing(command: "회의"))
        // then
        XCTAssertEqual(self.stubAgent.didLoadUsage, false)
        _ = observe
    }
}


// MARK: - currentUserPlan 릴레이 (#739)

extension AIAgentCommandViewModelImpleTests {

    // seeding 전(prepend nil) + billingUsecase 값 순서로 방출
    func test_currentUserPlan_relaysBillingUsecase() {
        // given
        let viewModel = self.makeViewModel(userPlan: BillingUserPlan() |> \.planId .~ .standard)
        var plans: [BillingUserPlan?] = []
        // when
        viewModel.currentUserPlan
            .sink(receiveValue: { plans.append($0) })
            .store(in: &self.cancelBag)
        // then
        XCTAssertEqual(plans.map { $0?.planId }, [nil, .standard])
    }
}


// MARK: - paywall 진입점 (#739)

extension AIAgentCommandViewModelImpleTests {

    func test_isPaywallAvailable_whenFlagOff_isFalse() {
        // given
        let viewModel = self.makeViewModel()
        // when
        let isAvailable = viewModel.isPaywallAvailable
        // then
        XCTAssertEqual(isAvailable, false)
    }

    func test_isPaywallAvailable_whenFlagOn_isTrue() {
        // given
        FeatureFlag.enable(.billingPaywall)
        let viewModel = self.makeViewModel()
        // when
        let isAvailable = viewModel.isPaywallAvailable
        // then
        XCTAssertEqual(isAvailable, true)
    }

    func test_showPlans_routesToPaywall() {
        // given
        let viewModel = self.makeViewModel()
        // when
        viewModel.showPlans()
        // then
        XCTAssertEqual(self.spyRouter.didRouteToPaywall, true)
    }
}


// MARK: - 구매 후 usage 재조회 릴레이 (#739)

extension AIAgentCommandViewModelImpleTests {

    private func makeViewModelWithBillingStub(
        userPlan: BillingUserPlan? = nil
    ) -> (AIAgentCommandViewModelImple, StubBillingUsecase) {
        let billingStub = StubBillingUsecase(stubUserPlan: userPlan)
        let viewModel = AIAgentCommandViewModelImple(
            orchestrationUsecase: self.stubAgent,
            billingUsecase: billingStub
        )
        viewModel.router = self.spyRouter
        return (viewModel, billingStub)
    }

    // 화면 진입 시점의 초기 seeding(첫 방출)만으로는 usage 를 재조회하지 않는다 — 안 그러면
    // 진입마다 불필요한 호출이 나간다
    func test_currentUserPlanFirstValue_doesNotRefreshUsage() {
        // given — 구독을 유지하려면 viewModel 을 살려둬야 한다([weak self] 라 dealloc 되면
        // 뒤이은 send() 가 무시된다)
        let (viewModel, _) = self.makeViewModelWithBillingStub(
            userPlan: BillingUserPlan() |> \.planId .~ .free
        )
        // when — 구독은 init 시점에 이미 시작됨(CurrentValueSubject 라 첫 값이 즉시 replay)
        // then
        XCTAssertFalse(self.stubAgent.didLoadUsage)
        _ = viewModel
    }

    // 구매 성공 등으로 보유 플랜이 바뀌면(첫 값 이후) usage 를 재조회해 게이지·dailyLimit 을
    // 최신화한다 — paywall 이 dismiss 후 onAppear 를 다시 못 태우는 상황(overFullScreen)의 대안
    func test_currentUserPlanChanged_afterFirstValue_refreshesUsage() {
        // given
        let (viewModel, billingStub) = self.makeViewModelWithBillingStub(
            userPlan: BillingUserPlan() |> \.planId .~ .free
        )
        XCTAssertFalse(self.stubAgent.didLoadUsage)
        // when
        billingStub.currentUserPlanSubject.send(BillingUserPlan() |> \.planId .~ .standard)
        // then
        XCTAssertTrue(self.stubAgent.didLoadUsage)
        _ = viewModel
    }
}
