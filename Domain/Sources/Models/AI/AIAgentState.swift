//
//  AIAgentState.swift
//  Domain
//
//  Created by sudo.park on 6/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - AIAgentState

public enum AIAgentState: Sendable {

    case idle                                                       // Voice 대기 (큰 마이크)
    case listening(level: Float?)                                   // 듣는 중, 텍스트 전
    case recognizing(text: String, level: Float?)                   // 실시간 인식 (텍스트 주인공)
    case voicePermissionDenied                                      // 마이크/음성 권한 거부
    case textInput(text: String)                                    // 키보드 입력
    case processing(command: String)                                // 서버 처리 중
    case confirm(command: String, action: AIConfirmCommandAction)   // 확인 필요
    case done(message: String?)                                     // 완료
    case failed(reason: String?)                                    // 실패
}
