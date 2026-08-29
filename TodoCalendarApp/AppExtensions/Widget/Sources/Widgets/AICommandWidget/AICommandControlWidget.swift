//
//  AICommandControlWidget.swift
//  TodoCalendarWidget
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import AppIntents


@available(iOS 18.0, *)
struct AICommandControlWidget: ControlWidget {

    nonisolated static let kind: String = "AICommandControlWidget"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenAICommandInputIntent()) {
                Label("Add with AI", image: "custom.calendar.badge.sparkles")
            }
        }
        .displayName("Add with AI")
    }
}
