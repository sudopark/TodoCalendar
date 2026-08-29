//
//  OpenAICommandInputIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import AppIntents


@available(iOS 18.0, *)
struct OpenAICommandInputIntent: OpenIntent {

    static let title: LocalizedStringResource = "Add with AI"

    @Parameter(title: "Target")
    var target: AIEntryTarget

    init() {
        self.target = .commandInput
    }

    init(target: AIEntryTarget) {
        self.target = target
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let url = self.target.link else { return .result() }
        await EnvironmentValues().openURL(url)
        return .result()
    }
}


@available(iOS 18.0, *)
enum AIEntryTarget: String, AppEnum {

    case commandInput

    var link: URL? {
        switch self {
        case .commandInput:
            return URL(string: "\(AppEnvironment.appScheme)://calendar/ai")
        }
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "AI entry"

    static let caseDisplayRepresentations: [AIEntryTarget: DisplayRepresentation] = [
        .commandInput: DisplayRepresentation("Add with AI")
    ]
}
