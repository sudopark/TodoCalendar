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
        repository: StubAICommandRepository = .init(),
        sharedItem: SharedCommandItem = .text("9월 10일 약속"),
        recognizedLines: [String] = [],
        recognizeError: (any Error)? = nil
    ) -> ShareCommandViewModel {
        let service = ShareCommandSubmitService(
            repository: repository,
            authStore: StubAuthStore(
                auth: hasAuth ? Auth(uid: "uid", accessToken: "token") : nil
            )
        )
        let recognizeService = StubImageTextRecognizeService()
        recognizeService.stubLines = recognizedLines
        recognizeService.stubError = recognizeError

        return ShareCommandViewModel(
            submitService: service,
            imageTextRecognizeService: recognizeService,
            loadSharedItem: { sharedItem },
            onClose: { }
        )
    }

    /// prepare()는 비동기라 완료 전에 send()를 부르면 canSubmit 가드에 걸린다.
    private func makePreparedViewModel(
        hasAuth: Bool = true,
        repository: StubAICommandRepository = .init(),
        sharedItem: SharedCommandItem = .text("9월 10일 약속"),
        recognizedLines: [String] = [],
        recognizeError: (any Error)? = nil
    ) async throws -> ShareCommandViewModel {
        let viewModel = self.makeViewModel(
            hasAuth: hasAuth, repository: repository,
            sharedItem: sharedItem,
            recognizedLines: recognizedLines, recognizeError: recognizeError
        )
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


// MARK: - 이미지 공유

extension ShareCommandViewModelTests {

    @Test func viewModel_whenImageShared_seedsRecognizedTextAndImageSource() async throws {
        // given
        let expect = expectConfirm("이미지 OCR 결과가 원문으로 실린다")
        let viewModel = self.makeViewModel(
            sharedItem: .image(Data([0x1])),
            recognizedLines: ["9월 10일", "치과 예약"]
        )

        // when
        let texts = try await self.outputs(expect, for: viewModel.sharedText) {
            viewModel.prepare()
        }

        // then
        #expect(texts.last == "9월 10일\n치과 예약")
        let source = try await self.firstOutput(
            expectConfirm("소스 축"), for: viewModel.source.compactMap { $0 }
        )
        #expect(source == .image(preview: nil))
    }

    @Test func viewModel_whenRecognizeFails_seedsEmptyText() async throws {
        // given
        let expect = expectConfirm("인식 실패도 빈 원문으로 수렴한다")
        let viewModel = self.makeViewModel(
            sharedItem: .image(Data([0x1])),
            recognizeError: RuntimeError("broken")
        )

        // when
        let texts = try await self.outputs(expect, for: viewModel.sharedText) {
            viewModel.prepare()
        }

        // then
        #expect(texts.last == "")
    }

    @Test func viewModel_whenTextShared_sourceIsText() async throws {
        // given
        let expect = expectConfirm("텍스트 공유의 소스 축")
        let viewModel = self.makeViewModel(sharedItem: .text("내일 회의"))

        // when
        let source = try await self.firstOutput(
            expect, for: viewModel.source.compactMap { $0 }
        ) {
            viewModel.prepare()
        }

        // then
        #expect(source == .text)
    }

    @Test("이미지 공유는 image_ocr로 전송된다")
    func viewModel_whenImageShared_submitsWithImageOcr() async throws {
        // given
        let repository = StubAICommandRepository()
        let viewModel = try await self.makePreparedViewModel(
            repository: repository,
            sharedItem: .image(Data([0x1])),
            recognizedLines: ["9월 10일 치과"]
        )
        let expect = expectConfirm("전송 완료")

        // when
        _ = try await self.outputs(expect, for: viewModel.sentMessage.compactMap { $0 }) {
            viewModel.send(sharedText: "9월 10일 치과", additionalInstruction: "")
        }

        // then
        #expect(repository.didProcessInterpretWithInputSource == .imageOcr)
    }
}


// MARK: - doubles

final class StubImageTextRecognizeService: ImageTextRecognizeService, @unchecked Sendable {

    var stubLines: [String] = []
    var stubError: (any Error)?
    var didRecognizeImageData: Data?

    func recognizeTextLines(in imageData: Data) async throws -> [String] {
        self.didRecognizeImageData = imageData
        if let error = self.stubError { throw error }
        return self.stubLines
    }
}
