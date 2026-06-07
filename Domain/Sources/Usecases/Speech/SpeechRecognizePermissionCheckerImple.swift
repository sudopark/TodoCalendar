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

    public func checkAuthorizationStatus() async -> SpeechRecognizeAuthStatus {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission
        return Self.combine(speech: speech, mic: mic)
    }

    public func requestAccess() async throws -> Bool {
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard micGranted else { return false }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        return speechStatus == .authorized
    }

    private static func combine(
        speech: SFSpeechRecognizerAuthorizationStatus,
        mic: AVAudioApplication.recordPermission
    ) -> SpeechRecognizeAuthStatus {
        if speech == .denied || mic == .denied {
            return .denied
        }
        if speech == .restricted {
            return .restricted
        }
        if speech == .authorized && mic == .granted {
            return .authorized
        }
        return .notDetermined
    }
}
