//
//  AICommandShortcutWidget.swift
//  TodoCalendarWidget
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import Extensions
import CommonPresentation
import Domain
import WidgetScenes


// MARK: - AICommandShortcutWidgetEntry

struct AICommandShortcutWidgetEntry: TimelineEntry {
    let date: Date
}

struct AICommandShortcutWidgetTimeLineProvider: TimelineProvider {

    func placeholder(in context: Context) -> AICommandShortcutWidgetEntry {
        return .init(date: Date())
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (AICommandShortcutWidgetEntry) -> Void
    ) {
        completion(.init(date: Date()))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<AICommandShortcutWidgetEntry>) -> Void
    ) {
        completion(Timeline(entries: [.init(date: Date())], policy: .never))
    }
}


// MARK: - AICommandShortcutWidgetView

struct AICommandShortcutWidgetView: View {

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch self.family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                AICommandCircularView()
            }
            .widgetAccentable()
        default:
            AICommandSmallView()
        }
    }
}


// MARK: - AICommandShortcutWidget

struct AICommandShortcutWidget: Widget {

    nonisolated static let kind: String = "AICommandShortcutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: AICommandShortcutWidgetTimeLineProvider()
        ) { _ in
            AICommandShortcutWidgetView()
                .containerBackground(.background, for: .widget)
                .widgetURL(AICommandEntryLink.url)
        }
        .supportedFamilies([.accessoryCircular, .systemSmall])
        .configurationDisplayName("widget.aiCommand::title".localized())
        .description("widget.aiCommand::explain".localized())
    }
}


// MARK: - preview

struct AICommandShortcutWidget_PreviewProvider: PreviewProvider {

    static var previews: some View {
        Group {
            AICommandShortcutWidgetView()
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .containerBackground(.background, for: .widget)

            AICommandShortcutWidgetView()
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(.background, for: .widget)
        }
    }
}
