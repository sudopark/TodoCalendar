//
//  OpenAICommandInputIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import AppIntents


// 컨트롤(컨트롤 센터·잠금화면·액션 버튼)에서 앱을 여는 진입점.
// OpenURLIntent는 universal link만 열 수 있어 custom scheme인 앱 딥링크를 못 태운다.
// OpenIntent로 앱을 띄운 뒤, 앱 안에서 기존 딥링크 경로를 그대로 태운다.
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

    // 이 파일은 위젯 확장 타겟에서도 컴파일된다 — UIApplication.shared는 확장에서 금지라 쓸 수 없다.
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
