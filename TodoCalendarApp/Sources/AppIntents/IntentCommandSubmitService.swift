//
//  IntentCommandSubmitService.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


struct IntentCommandSubmitService: Sendable {

    private let repository: any AICommandRepository
    private let authStore: any AuthStore
    private let settingRepository: any CalendarSettingRepository

    init(
        repository: any AICommandRepository,
        authStore: any AuthStore,
        settingRepository: any CalendarSettingRepository
    ) {
        self.repository = repository
        self.authStore = authStore
        self.settingRepository = settingRepository
    }

    func submit(_ commandText: String) async throws {
        guard self.authStore.loadCurrentAuth() != nil
        else { throw AICommandSubmitFailReason.notSignedIn }

        guard await self.hasNoPendingRequest()
        else { throw AICommandSubmitFailReason.previousRequestPending }

        guard await self.hasRemainingCredit()
        else { throw AICommandSubmitFailReason.limitExceeded }

        let timeZone = self.settingRepository.loadUserSelectedTImeZone() ?? .current
        let jobId: String
        do {
            jobId = try await self.repository.processCommand(
                commandText, timeZone: timeZone.identifier
            )
        } catch {
            throw AICommandSubmitFailReason(error)
        }

        try await self.updateProcessingCommand(jobId: jobId)
    }

    private func hasNoPendingRequest() async -> Bool {
        do {
            return try await self.repository.loadProcessingAICommand() == nil
        } catch {
            return false
        }
    }

    private func hasRemainingCredit() async -> Bool {
        // 조회 실패는 통과 — 서버가 최종 판정한다.
        guard let usage = try? await self.repository.loadUsage() else { return true }
        return !usage.isCreditExhausted
    }

    private func updateProcessingCommand(jobId: String) async throws {
        do {
            try await self.repository.updateProcessingAICommand(
                .init(jobId: jobId, isConfirmJob: false)
            )
        } catch {
            throw AICommandSubmitFailReason.processingCommandRecordFailed
        }
    }
}
