//
//  SpeechRecognizePermissionChecker.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - SpeechRecognizeAuthStatus

public struct SpeechRecognizeAuthError: Error {
    public enum Reason: Sendable {
        case restricted
        case denied
    }
    public let micNotAvail: Reason?
    public let speechNotAvail: Reason?
    public init(micNotAvail: Reason? = nil, speechNotAvail: Reason? = nil) {
        self.micNotAvail = micNotAvail
        self.speechNotAvail = speechNotAvail
    }
}


// MARK: - SpeechRecognizePermissionChecker

public protocol SpeechRecognizePermissionChecker: Sendable {

    func requestAccess() async throws
}
