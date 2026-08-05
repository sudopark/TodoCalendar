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

    // ProcessingAICommand는 단일 행이라, 앞선 요청이 남았는데 새로 보내면 앱이 이어받을
    // 근거가 덮여 결과가 유실된다. 유무 확인 자체가 실패해도 보내지 않는다.
    private func hasNoPendingRequest() async -> Bool {
        do {
            return try await self.repository.loadProcessingAICommand() == nil
        } catch {
            return false
        }
    }

    // 인텐트는 응답 직후 죽으므로 이 기록이 앱으로 넘기는 유일한 인계 채널이다.
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
