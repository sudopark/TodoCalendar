//
//  AIAgentImageCommandViewModelImpleTests.swift
//  AIAgentSceneTests
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import Extensions
import UnitTestHelpKit

@testable import AIAgentScene


final class AIAgentImageCommandViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let spyRouter = SpyAIAgentImageCommandRouter()
    private let stubOrchestration = StubAIAgentOrchestrationUsecase()

    private func makeViewModel(
        recognizedLines: [String] = ["상품명 아메리카노", "8월 12일 14:00"],
        recognizeError: (any Error)? = nil,
        submitError: (any Error)? = nil
    ) -> AIAgentImageCommandViewModelImple {
        let service = StubImageTextRecognizeService(
            lines: recognizedLines, error: recognizeError
        )
        self.stubOrchestration.stubImageSubmitError = submitError
        let viewModel = AIAgentImageCommandViewModelImple(
            imageData: Data(),
            imageTextRecognizeService: service,
            aiAgentOrchestrationUsecase: self.stubOrchestration,
            billingUsecase: StubBillingUsecase()
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}


// MARK: - 인식 진행

extension AIAgentImageCommandViewModelImpleTests {

    @Test func viewModel_whenPrepare_movesFromRecognizingToEditing() async throws {
        // given
        let expect = expectConfirm("recognizing → editing 순으로 방출된다")
        expect.count = 2
        let viewModel = self.makeViewModel()

        // when
        let stages = try await self.outputs(expect, for: viewModel.stage) {
            viewModel.prepare()
        }

        // then
        #expect(stages.first == .recognizing)
        #expect(stages.last == .editing(text: "상품명 아메리카노\n8월 12일 14:00"))
    }

    @Test func viewModel_whenNoTextRecognized_showsNoTextFound() async throws {
        // given
        let expect = expectConfirm("빈 결과면 noTextFound")
        expect.count = 2
        let viewModel = self.makeViewModel(recognizedLines: [])

        // when
        let stages = try await self.outputs(expect, for: viewModel.stage) {
            viewModel.prepare()
        }

        // then
        #expect(stages.last == .noTextFound)
    }

    @Test func viewModel_whenRecognizeCancelled_doesNotShowErrorAndStaysRecognizing() async throws {
        // given
        // 구독은 초기 recognizing을 즉시 버퍼링해 count 1을 바로 채우므로,
        // action 안에서 인식 Task의 catch 분기가 실행될 시간을 벌어야
        // 회귀(취소를 noTextFound로 잘못 보내는 경우) 시 추가 방출을 같은 구독이 잡아 count 불일치로 실패한다.
        let expect = expectConfirm("취소는 recognizing 유지, 에러로 알리지 않는다")
        let viewModel = self.makeViewModel(recognizeError: CancellationError())

        // when
        let stages = try await self.outputs(expect, for: viewModel.stage) {
            viewModel.prepare()
            try await Task.sleep(for: .milliseconds(50))
        }

        // then
        #expect(stages == [.recognizing])
        #expect(self.spyRouter.didShowError == nil)
        #expect(self.spyRouter.didClosed == nil)
    }

    @Test func viewModel_whenRecognizeFails_showsNoTextFound() async throws {
        // given
        let expect = expectConfirm("일반 실패는 noTextFound로 수렴")
        expect.count = 2
        let viewModel = self.makeViewModel(recognizeError: RuntimeError("recognize failed"))

        // when
        let stages = try await self.outputs(expect, for: viewModel.stage) {
            viewModel.prepare()
        }

        // then
        #expect(stages.last == .noTextFound)
        #expect(self.spyRouter.didShowError == nil)
        #expect(self.spyRouter.didClosed == nil)
    }
}


// MARK: - 제출

extension AIAgentImageCommandViewModelImpleTests {

    @Test func viewModel_whenSend_submitsTextAndInstructionSeparately() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.send(text: "영수증 내용", additionalInstruction: "일정으로 등록해줘")

        // then
        #expect(self.stubOrchestration.didSubmitImageCommandWith?.text == "영수증 내용")
        #expect(self.stubOrchestration.didSubmitImageCommandWith?.instruction == "일정으로 등록해줘")
        #expect(self.spyRouter.didClosed == true)
    }

    @Test func viewModel_whenSubmitFailsByTooLongText_showsToastAndKeepsScene() async throws {
        // given
        let viewModel = self.makeViewModel(submitError: AIImageCommandSubmitFailReason.textTooLong)

        // when
        viewModel.send(text: "영수증 내용", additionalInstruction: "")

        // then
        #expect(self.spyRouter.didShowToastWithMessage != nil)
        #expect(self.spyRouter.didClosed != true)
    }
}
