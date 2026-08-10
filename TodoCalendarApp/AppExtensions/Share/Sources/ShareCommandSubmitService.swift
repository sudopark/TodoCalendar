//
//  ShareCommandSubmitService.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import Repository


enum ShareSubmitPrecondition {
    case ready
    case needSignIn
    /// 앞선 요청이 아직 처리 중이거나, 결과를 유저가 확인하지 않았다.
    case previousRequestPending
    case creditExhausted
}


enum ShareSubmitFailure: Error, Equatable {
    case emptyCommand
    case sharedTextTooLong
    case additionalInstructionTooLong
    /// job은 서버에 만들어졌지만 로컬 기록에 실패해 앱이 결과를 이어받을 수 없다.
    case createdButNotTrackable
}


final class ShareCommandSubmitService {

    private enum Constant {
        static let maxSharedTextLength: Int = 10000
        static let maxAdditionalInstructionLength: Int = 1000
    }

    private let repository: any AICommandRepository
    private let authStore: any AuthStore

    init(
        repository: any AICommandRepository,
        authStore: any AuthStore
    ) {
        self.repository = repository
        self.authStore = authStore
    }
}

extension ShareCommandSubmitService {

    func checkPrecondition() async -> ShareSubmitPrecondition {
        guard self.authStore.loadCurrentAuth() != nil
        else { return .needSignIn }

        do {
            let pending = try await self.repository.loadProcessingAICommand()
            guard pending == nil else { return .previousRequestPending }
        } catch {
            // 앞선 요청 유무를 확인 못 했으면 통과시키지 않는다 —
            // 통과 후 제출하면 앱이 추적 중인 job을 덮어써 결과가 유실된다.
            return .previousRequestPending
        }

        // 조회 실패는 통과 — 결과 유실 위험이 없고 서버가 최종 판정한다.
        let usage = try? await self.repository.loadUsage()
        return usage?.isCreditExhausted == true ? .creditExhausted : .ready
    }

    func submit(
        sharedText: String,
        additionalInstruction: String,
        inputSource: AICommandInputSource = .text
    ) async throws {
        let text = sharedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty
        else { throw ShareSubmitFailure.emptyCommand }
        guard text.count <= Constant.maxSharedTextLength
        else { throw ShareSubmitFailure.sharedTextTooLong }

        let trimmedInstruction = additionalInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction: String? = trimmedInstruction.isEmpty ? nil : trimmedInstruction
        guard (instruction?.count ?? 0) <= Constant.maxAdditionalInstructionLength
        else { throw ShareSubmitFailure.additionalInstructionTooLong }

        let jobId = try await self.repository.processInterpretCommand(
            text: text,
            additionalInstruction: instruction,
            inputSource: inputSource,
            timeZone: TimeZone.current.identifier
        )
        // 확장은 시트를 닫으면 죽으므로 이 기록이 앱으로 넘기는 유일한 인계 채널이다.
        // 본체는 기록이 실패해도 in-memory 폴링이 결과를 보여주지만 여기는 폴백이 없어,
        // "보냈어요"로 속이지 않고 추적 불가를 알린다.
        do {
            try await self.repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: false)
            )
        } catch {
            throw ShareSubmitFailure.createdButNotTrackable
        }
    }
}
