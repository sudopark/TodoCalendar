//
//  AICommandShortcutWidget.swift
//  TodoCalendarWidget
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import WidgetKit
import SwiftUI
import AppIntents
import Extensions
import CommonPresentation
import Domain
import WidgetScenes


// MARK: - AICommandShortcutWidgetEntry

struct AICommandShortcutWidgetEntry: TimelineEntry {
    let date: Date
    var look: WidgetLook = .init(globalSetting: .init())
    var isCustomStyleLocked: Bool = false

    var widgetURL: URL? {
        return self.isCustomStyleLocked ? WidgetStyleLicenseLink.url : AICommandEntryLink.url
    }

    var backgroundShape: AnyShapeStyle {
        return WidgetBackgroundStyle(self.look.background).shape
    }
}

struct AICommandShortcutWidgetTimeLineProvider: AppIntentTimelineProvider {

    typealias Intent = AICommandWidgetConfigurationIntent

    func placeholder(in context: Context) -> AICommandShortcutWidgetEntry {
        return self.entry(context.family, .default)
    }

    func snapshot(
        for configuration: AICommandWidgetConfigurationIntent,
        in context: Context
    ) async -> AICommandShortcutWidgetEntry {
        return self.entry(context.family, configuration.resolvedStyle)
    }

    func timeline(
        for configuration: AICommandWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<AICommandShortcutWidgetEntry> {
        let style = configuration.resolvedStyle
        let entry = self.entry(context.family, style)
        return Timeline(entries: [entry], policy: style.aiCommandWidgetRefreshPolicy(at: entry.date))
    }

    private func entry(
        _ family: WidgetFamily, _ style: WidgetStyleId.Style
    ) -> AICommandShortcutWidgetEntry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let variant: WidgetVariant =
            family == .accessoryCircular ? .aiCommandCircular : .aiCommandSmall
        let now = Date()
        let globalSetting = builder.loadWidgetAppearanceSetting()
        do {
            let appliedStyle = try builder.resolveWidgetStyle(of: variant, style: style, at: now)
            return .init(
                date: now,
                look: .init(globalSetting: globalSetting, appliedStyle: appliedStyle)
            )
        } catch {
            return .init(
                date: now,
                look: .init(globalSetting: globalSetting),
                isCustomStyleLocked: true
            )
        }
    }
}


// MARK: - 갱신 정책

extension WidgetStyleId.Style {

    /// 커스텀은 사용권 만료로 잠길 수 있어 정규 갱신을 받는다
    func aiCommandWidgetRefreshPolicy(at now: Date) -> TimelineReloadPolicy {
        return self == .default ? .never : .after(now.nextUpdateTime)
    }
}


// MARK: - AICommandShortcutWidgetView

struct AICommandShortcutWidgetView: View {

    @Environment(\.widgetFamily) private var family

    let look: WidgetLook
    var isCustomStyleLocked: Bool = false

    var body: some View {
        switch self.family {
        case .systemSmall where self.isCustomStyleLocked:
            WidgetCustomStyleLockedView(family: .small)
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
        AppIntentConfiguration(
            kind: Self.kind,
            intent: AICommandWidgetConfigurationIntent.self,
            provider: AICommandShortcutWidgetTimeLineProvider()
        ) { entry in
            AICommandShortcutWidgetView(
                look: entry.look, isCustomStyleLocked: entry.isCustomStyleLocked
            )
                .containerBackground(entry.backgroundShape, for: .widget)
                .widgetURL(entry.widgetURL)
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
