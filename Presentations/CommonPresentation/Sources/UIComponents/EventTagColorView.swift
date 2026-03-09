//
//  EventTagColorView.swift
//  CommonPresentation
//
//  Created by sudo.park on 2026/03/10.
//

import SwiftUI
import Domain


// MARK: - EventTagColorView

/// 색상 결정만 담당하는 뷰. 결정된 Color를 content 클로저에 전달.
/// 도트/막대 등 실제 형태는 호출부에서 결정.
/// 내부에서 EventTagColorSource 구체 타입으로 분기해 ViewAppearance의 적절한 메서드를 호출.
public struct EventTagColorView<Content: View>: View {

    @Environment(ViewAppearance.self) private var appearance
    private let source: any EventTagColorSource
    @ViewBuilder private let content: (Color) -> Content

    public init(
        _ source: any EventTagColorSource,
        @ViewBuilder content: @escaping (Color) -> Content
    ) {
        self.source = source
        self.content = content
    }

    public var body: some View {
        content(resolvedColor.asColor)
    }

    private var resolvedColor: UIColor {
        switch source {
        case let google as GoogleCalendarEventColorSource:
            return appearance.googleEventColor(google.colorId, google.calendarId)
        case let tagId as EventTagId:
            return appearance.color(tagId)
        default:
            return .clear
        }
    }
}
