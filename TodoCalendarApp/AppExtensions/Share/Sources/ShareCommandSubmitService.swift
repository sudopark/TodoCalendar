//
//  ShareCommandSubmitService.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository
import Extensions


enum ShareSubmitPrecondition {
    case ready
    case needSignIn
    /// 앞선 요청이 아직 처리 중이거나, 결과를 유저가 확인하지 않았다.
    case previousRequestPending
}


final class ShareCommandSubmitService {

    private let repository: any AICommandRepository
    private let authStore: AuthStoreImple

    init(
        repository: any AICommandRepository,
        authStore: AuthStoreImple
    ) {
        self.repository = repository
        self.authStore = authStore
    }
}

extension ShareCommandSubmitService {

    func checkPrecondition() async -> ShareSubmitPrecondition {
        guard self.authStore.loadCurrentAuth() != nil
        else { return .needSignIn }

        let pending = try? await self.repository.loadProcessingAICommand()
        guard pending == nil
        else { return .previousRequestPending }

        return .ready
    }

    func submit(_ text: AIShareCommandText) async throws {
        guard !text.isEmpty
        else { throw RuntimeError(key: "Share.emptyCommand", "shared text is empty") }

        let jobId = try await self.repository.processCommand(
            text.commandText,
            timeZone: TimeZone.current.identifier
        )
        // job은 이미 서버에 만들어졌다 — 로컬 기록 실패로 전체를 실패시키지 않는다
        try? await self.repository.updateProcessingAICommand(
            .init(jobId: jobId, isConfirmJob: false)
        )
    }
}
