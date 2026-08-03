//
//  AIAgentState.swift
//  Domain
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - AIAgentInputMethod

public enum AIAgentInputMethod: Sendable, Equatable {
    case voice
    case keyboard
}


// MARK: - AIAgentState

public enum AIAgentState: Sendable {

    case idle                                                       // command 없음 (초기/리셋)
    case listening(AIAgentInputMethod)                              // 입력 대기 (voice/keyboard)
    case processing(command: String)                                // 서버 처리 중
    case confirm(command: String, message: String?, action: AIConfirmCommandAction, expireTime: Date?)  // 확인 필요 (nil = 만료 시각 불명 — 카운트다운 없음). 만료 여부는 expireTime을 과거와 비교해 소비자가 파생한다.
    case done(command: String, message: String?)                    // 완료
    case failed(command: String, reason: String?, errorCode: ServerErrorModel.ErrorCode?)   // 실패
}
