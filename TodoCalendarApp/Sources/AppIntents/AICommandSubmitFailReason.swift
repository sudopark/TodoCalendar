//
//  AICommandSubmitFailReason.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


enum AICommandSubmitFailReason: Error, Equatable {
    case notSignedIn
    case limitExceeded
    case previousRequestPending
    /// 서버 job은 만들어졌지만 ProcessingAICommand 기록에 실패했다.
    /// 재시도를 유도하면 중복 job에 크레딧이 두 번 나간다.
    case processingCommandRecordFailed
    case unknown
}

extension AICommandSubmitFailReason {

    init(_ error: any Error) {
        switch (error as? ServerErrorModel)?.code {
        case .dailyLimitExceeded:
            self = .limitExceeded

        case .unauthorized, .invalidAccessKey:
            // 로컬 Auth 레코드는 남아있는데 서버 세션이 죽은 경우 — 무한 재시도로
            // 유저를 몰아넣지 않도록 로그인 유도 문구로 떨어뜨린다.
            self = .notSignedIn

        default:
            self = .unknown
        }
    }
}
