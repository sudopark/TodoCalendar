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
    var look: WidgetLook = .init(globalSetting: .init())

    var backgroundShape: AnyShapeStyle {
        return WidgetBackgroundStyle(self.look.background).shape
    }
}

struct AICommandShortcutWidgetTimeLineProvider: TimelineProvider {

    func placeholder(in context: Context) -> AICommandShortcutWidgetEntry {
        return self.entry(context.family)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (AICommandShortcutWidgetEntry) -> Void
    ) {
        completion(self.entry(context.family))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<AICommandShortcutWidgetEntry>) -> Void
    ) {
        completion(Timeline(entries: [self.entry(context.family)], policy: .never))
    }

    private func entry(_ family: WidgetFamily) -> AICommandShortcutWidgetEntry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let variant: WidgetVariant =
            family == .accessoryCircular ? .aiCommandCircular : .aiCommandSmall
        return .init(
            date: Date(),
            look: .init(
                globalSetting: builder.loadWidgetAppearanceSetting(),
                appliedStyle: builder.resolveWidgetStyle(of: variant)
            )
        )
    }
}


// MARK: - AICommandShortcutWidgetView

struct AICommandShortcutWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let look: WidgetLook

    var body: some View {
        switch self.family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                AICommandCircularView()
            }
            .widgetAccentable()
        default:
            AICommandSmallView(look: self.look)
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
            AICommandShortcutWidgetView(look: entry.look)
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
            AICommandShortcutWidgetView(look: .init(globalSetting: .init()))
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .containerBackground(.background, for: .widget)

            AICommandShortcutWidgetView(look: .init(globalSetting: .init()))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(.background, for: .widget)
        }
    }
}
