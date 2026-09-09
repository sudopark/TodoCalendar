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
    var setting: WidgetAppearanceSettings = .init()

    var backgroundShape: AnyShapeStyle {
        return WidgetBackgroundStyle(self.setting.background).shape
    }
}

struct AICommandShortcutWidgetTimeLineProvider: TimelineProvider {

    func placeholder(in context: Context) -> AICommandShortcutWidgetEntry {
        return self.entry()
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (AICommandShortcutWidgetEntry) -> Void
    ) {
        completion(self.entry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<AICommandShortcutWidgetEntry>) -> Void
    ) {
        completion(Timeline(entries: [self.entry()], policy: .never))
    }

    private func entry() -> AICommandShortcutWidgetEntry {
        let setting = WidgetViewModelProviderBuilder(base: .init())
            .loadWidgetAppearanceSetting()
        return .init(date: Date(), setting: setting)
    }
}


// MARK: - AICommandShortcutWidgetView

struct AICommandShortcutWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let setting: WidgetAppearanceSettings

    var body: some View {
        switch self.family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                AICommandCircularView()
            }
            .widgetAccentable()
        default:
            AICommandSmallView(setting: self.setting)
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
        ) { entry in
            AICommandShortcutWidgetView(setting: entry.setting)
                .containerBackground(entry.backgroundShape, for: .widget)
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
            AICommandShortcutWidgetView(setting: .init())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .containerBackground(.background, for: .widget)

            AICommandShortcutWidgetView(setting: .init())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(.background, for: .widget)
        }
    }
}
