//
//  ShareCommandViewModelTests.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Testing
import Domain
import Extensions
import UnitTestHelpKit

@testable import TodoCalendarAppShare


final class ShareCommandViewModelTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeViewModel(
        hasAuth: Bool = true,
        repository: StubAICommandRepository = .init()
    ) -> ShareCommandViewModel {
        let service = ShareCommandSubmitService(
            repository: repository,
            authStore: StubAuthStore(
                auth: hasAuth ? Auth(uid: "uid", accessToken: "token") : nil
            )
        )
        return ShareCommandViewModel(
            submitService: service,
            loadSharedText: { "9월 10일 약속" },
            onClose: { }
        )
    }

    /// prepare()는 비동기라 완료 전에 send()를 부르면 canSubmit 가드에 걸린다.
    private func makePreparedViewModel(
        hasAuth: Bool = true,
        repository: StubAICommandRepository = .init()
    ) async throws -> ShareCommandViewModel {
        let viewModel = self.makeViewModel(hasAuth: hasAuth, repository: repository)
        let expect = expectConfirm("준비 완료")
        expect.count = 2
        _ = try await self.outputs(expect, for: viewModel.isPreparing) {
            viewModel.prepare()
        }
        return viewModel
    }
}


// MARK: - 준비

extension ShareCommandViewModelTests {

    @Test("미로그인이면 차단 문구를 노출한다")
    func prepare_whenNotSignedIn_showsBlockedMessage() async throws {
        // given
        let expect = expectConfirm("차단 문구 방출")
        expect.count = 2
        let viewModel = self.makeViewModel(hasAuth: false)

        // when
        let messages = try await self.outputs(expect, for: viewModel.blockedMessage) {
            viewModel.prepare()
        }

        // then
        #expect(messages.last ?? nil == "share.ai::needSignIn".localized())
    }
}


// MARK: - 전송

extension ShareCommandViewModelTests {

    @Test("전송에 성공하면 완료 문구를 노출한다")
    func send_whenSucceed_showsSentMessage() async throws {
        // given
        let viewModel = try await self.makePreparedViewModel()
        let expect = expectConfirm("완료 문구 방출")
        expect.count = 2

        // when
        let messages = try await self.outputs(expect, for: viewModel.sentMessage) {
            viewModel.send(sharedText: "9월 10일 약속", additionalInstruction: "")
        }

        // then
        #expect(messages.last ?? nil == "share.ai::sent".localized())
    }

    @Test("원문이 상한을 넘으면 전용 문구를 노출한다")
    func send_whenTextTooLong_showsDedicatedMessage() async throws {
        // given
        let viewModel = try await self.makePreparedViewModel()
        let expect = expectConfirm("상한 문구 방출")
        expect.count = 3

        // when
        let messages = try await self.outputs(expect, for: viewModel.failureMessage) {
            viewModel.send(
                sharedText: String(repeating: "가", count: 10001),
                additionalInstruction: ""
            )
        }

        // then
        #expect(messages.last ?? nil == "share.ai::textTooLong".localized())
    }

    @Test("부가지시가 상한을 넘으면 전용 문구를 노출한다")
    func send_whenInstructionTooLong_showsDedicatedMessage() async throws {
        // given
        let viewModel = try await self.makePreparedViewModel()
        let expect = expectConfirm("상한 문구 방출")
        expect.count = 3

        // when
        let messages = try await self.outputs(expect, for: viewModel.failureMessage) {
            viewModel.send(
                sharedText: "9월 10일 약속",
                additionalInstruction: String(repeating: "가", count: 1001)
            )
        }

        // then
        #expect(messages.last ?? nil == "share.ai::instructionTooLong".localized())
    }

    @Test("제출이 실패하면 일반 실패 문구를 노출한다")
    func send_whenSubmitFails_showsFailureMessage() async throws {
        // given
        let repository = makeStubAICommandRepository(
            processFailWith: RuntimeError("network is down")
        )
        let viewModel = try await self.makePreparedViewModel(repository: repository)
        let expect = expectConfirm("실패 문구 방출")
        expect.count = 3

        // when
        let messages = try await self.outputs(expect, for: viewModel.failureMessage) {
            viewModel.send(sharedText: "9월 10일 약속", additionalInstruction: "")
        }

        // then
        #expect(messages.last ?? nil == "share.ai::failed".localized())
    }

    @Test("제출이 실패해도 전송 상태를 되돌려 재시도를 허용한다")
    func send_whenSubmitFails_resetsSendingState() async throws {
        // given
        let repository = makeStubAICommandRepository(
            processFailWith: RuntimeError("network is down")
        )
        let viewModel = try await self.makePreparedViewModel(repository: repository)
        let expect = expectConfirm("전송 상태 복귀")
        expect.count = 3

        // when
        let isSendings = try await self.outputs(expect, for: viewModel.isSending) {
            viewModel.send(sharedText: "9월 10일 약속", additionalInstruction: "")
        }

        // then
        #expect(isSendings == [false, true, false])
    }

    @Test("job 기록에 실패하면 추적 불가 문구를 노출한다")
    func send_whenRecordFails_showsUntrackedMessage() async throws {
        // given
        let repository = makeStubAICommandRepository(shouldFailUpdatePending: true)
        let viewModel = try await self.makePreparedViewModel(repository: repository)
        let expect = expectConfirm("추적 불가 문구 방출")
        expect.count = 2

        // when
        let messages = try await self.outputs(expect, for: viewModel.sentMessage) {
            viewModel.send(sharedText: "9월 10일 약속", additionalInstruction: "")
        }

        // then
        #expect(messages.last ?? nil == "share.ai::sentButUntracked".localized())
    }
}
