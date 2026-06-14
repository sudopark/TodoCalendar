//
//  AIAgentState.swift
//  Domain
//
//  Created by sudo.park on 6/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - AIAgentState

public enum AIAgentState: Sendable {

    case idle                                                       // command 없음 (초기/리셋)
    case processing(command: String)                                // 서버 처리 중
    case confirm(command: String, action: AIConfirmCommandAction)   // 확인 필요
    case done(message: String?)                                     // 완료
    case failed(reason: String?)                                    // 실패
}
