//
//  TodoCalendarAppShortcuts.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import AppIntents


struct TodoCalendarAppShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendAICommandIntent(),
            phrases: [
                "Hey \(.applicationName)",
                "Request in \(.applicationName)",
                "Ask \(.applicationName)",
                "Send a request to \(.applicationName)",
                "Add with AI in \(.applicationName)"
            ],
            shortTitle: "Send",
            systemImageName: "sparkles"
        )
    }
}
