//
//  AIImageCommandSubmitFailReason.swift
//  Domain
//
//  Created by sudo.park on 8/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 서버(POST /v1/ai/command/interpret)가 같은 조건으로 400을 낸다.
/// 전송 전에 걸러 "실패했어요" 대신 무엇을 줄여야 하는지 알린다.
public enum AIImageCommandSubmitFailReason: Error, Equatable {
    case emptyText
    case textTooLong
    case instructionTooLong
    case busy
}
