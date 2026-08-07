//
//  AIJobRefreshUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Scenes


protocol AIJobRefreshUsecase: Sendable {

    func change(factory: any UsecaseFactory)

    func handleJobStatusChanged(_ jobId: String)
    func refreshProcessingJobIfNeeded()
    func handleSignedOut() async
}


final class AIJobRefreshUsecaseImple: AIJobRefreshUsecase, @unchecked Sendable {

    private var usecaseFactory: (any UsecaseFactory)?

    init() { }
}


extension AIJobRefreshUsecaseImple {

    func change(factory: any UsecaseFactory) {
        self.usecaseFactory = factory
    }

    func handleJobStatusChanged(_ jobId: String) {
        self.usecaseFactory?.aiAgentOrchestrationUsecase
            .handleJobStatusChanged(jobId)
    }

    func refreshProcessingJobIfNeeded() {
        self.usecaseFactory?.aiAgentOrchestrationUsecase
            .refreshProcessingJobIfNeeded()
    }

    // 팩토리 교체 전에 불려야 로그인 세션의 오케스트레이션이 정리 대상이 된다
    func handleSignedOut() async {
        await self.usecaseFactory?.aiAgentOrchestrationUsecase
            .handleSignedOut()
    }
}
