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
                "Add with AI in \(.applicationName)",
                "Add a schedule in \(.applicationName)",
                "Add a to-do in \(.applicationName)"
            ],
            shortTitle: "Add with AI",
            systemImageName: "sparkles"
        )
    }
}
