//
//  MonthWidgetConfigurationIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import AppIntents
import Domain


struct MonthWidgetConfigurationIntent: WidgetConfigurationIntent {

    static let title: LocalizedStringResource = ""

    @Parameter(title: "Style", default: nil)
    var style: MonthStyleEntity?

    /// 미선택도 해석 실패도 기본 스타일로 내려, 읽는 쪽에 분기를 남기지 않는다.
    var resolvedStyle: WidgetStyleId.Style {
        return self.style
            .flatMap { WidgetStyleId.Style(entityId: $0.id) }
            ?? .default
    }
}
