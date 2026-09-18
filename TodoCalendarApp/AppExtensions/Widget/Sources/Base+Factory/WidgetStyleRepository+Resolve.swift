//
//  WidgetStyleRepository+Resolve.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


extension WidgetStyleRepository {

    /// 표시 항목도 배경색도 이 한 스타일에서 읽는다 — 필드 단위로 내려가면
    /// 편집 화면·프리뷰·실제 위젯이 서로 다른 값을 그린다.
    func resolveStyle(
        of variant: WidgetVariant, style: WidgetStyleId.Style
    ) -> WidgetStyle? {
        guard let selected = self.savedStyle(variant, style) else {
            return style == .default ? nil : self.savedStyle(variant, .default)
        }
        return selected
    }

    private func savedStyle(
        _ variant: WidgetVariant, _ style: WidgetStyleId.Style
    ) -> WidgetStyle? {
        return self.loadStyle(for: .init(variant: variant, style: style))
    }
}
