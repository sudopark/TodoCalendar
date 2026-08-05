//
//  SendAICommandIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import AppIntents


struct SendAICommandIntent: AppIntent {

    static let title: LocalizedStringResource = "Add with AI"

    static let description = IntentDescription(
        "Send what you say to AI and let it create your events and to-dos."
    )

    // 앱을 열지 않고 백그라운드에서 커맨드만 등록한다. 결과는 푸시로 전달된다.
    static let openAppWhenRun: Bool = false

    @Parameter(
        title: "Command",
        requestValueDialog: IntentDialog("What would you like to add?")
    )
    var commandText: String

    init() { }

    init(commandText: String) {
        self.commandText = commandText
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = AICommandIntentFactory().makeSubmitService()
        do {
            try await service.submit(self.commandText)
            return .result(dialog: IntentDialog("Got it. I'll notify you when it's done."))
        } catch {
            let reason = error as? AICommandSubmitFailReason ?? .unknown
            return .result(dialog: reason.dialog)
        }
    }
}


extension AICommandSubmitFailReason {

    var dialog: IntentDialog {
        switch self {
        case .notSignedIn:
            return IntentDialog("Sign in to the app first to use AI.")
        case .limitExceeded:
            return IntentDialog("You've used up your AI credits for today.")
        case .previousRequestPending:
            return IntentDialog("A previous request is still pending. Check the app to review it.")
        case .processingCommandRecordFailed:
            // job은 이미 서버에 있다 — 재시도를 유도하면 중복 job에 크레딧이 두 번 나간다.
            return IntentDialog("Sent, but the app can't track the result. Check your calendar after a moment.")
        case .unknown:
            return IntentDialog("Something went wrong. Please try again.")
        }
    }
}
