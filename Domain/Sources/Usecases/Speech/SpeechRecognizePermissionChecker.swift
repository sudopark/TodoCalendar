//
//  SpeechRecognizePermissionChecker.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - SpeechRecognizeAuthStatus

public enum SpeechRecognizeAuthStatus: Sendable {
    case notDetermined
    case denied
    case restricted
    case authorized
}


// MARK: - SpeechRecognizePermissionChecker

public protocol SpeechRecognizePermissionChecker: Sendable {

    // mic + speech recognition 권한을 함께 확인 (가장 보수적인 상태 반환)
    func checkAuthorizationStatus() async -> SpeechRecognizeAuthStatus

    // mic → speech 순차 요청. 둘 다 grant되어야 true
    func requestAccess() async throws -> Bool
}
