//
//  SpeechRecognizePermissionCheckerImple.swift
//  Domain
//
//  Created by sudo.park on 6/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Speech
import AVFoundation


public final class SpeechRecognizePermissionCheckerImple: SpeechRecognizePermissionChecker, @unchecked Sendable {

    public init() {}

    public func requestAccess() async throws {
        let mic = await self.requestMicAccessIfNeed()
        let speech = await self.requestSpeechAccessIfNeed()
        
        switch (mic, speech) {
        case (.grant, .grant):
            return
        case (_, .restricted):
            throw SpeechRecognizeAuthError(speechNotAvail: .restricted)
        default:
            throw SpeechRecognizeAuthError(
                micNotAvail: mic == .denied ? .denied : nil,
                speechNotAvail: speech == .denied ? .denied : nil
            )
        }
    }
    
    private enum AuthorizationStatus {
        case restricted
        case grant
        case denied
    }
    
    private func requestMicAccessIfNeed() async -> AuthorizationStatus {
        
        let mic = AVAudioApplication.shared.recordPermission
        switch mic {
        case .denied: return .denied
        case .granted: return .grant
        case .undetermined:
            let isGrant = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            return isGrant ? .grant : .denied
        @unknown default:
            return .denied
        }
    }
    
    private func requestSpeechAccessIfNeed() async -> AuthorizationStatus {
        let speech = SFSpeechRecognizer.authorizationStatus()
        switch speech {
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .grant
        case .notDetermined:
            let status  = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            return status == .authorized ? .grant : .denied
        @unknown default:
            return .denied
        }
    }
}
