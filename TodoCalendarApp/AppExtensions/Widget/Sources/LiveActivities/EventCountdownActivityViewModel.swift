//
//  EventCountdownActivityViewModel.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SwiftUI
import CommonPresentation


struct EventCountdownActivityViewModel {

    let eventName: String
    let eventTimeText: String
    let eventDate: Date
    let startDate: Date
    let subtitle: String?
    let tagColor: Color
    let usesDarkGlyph: Bool
    let showsCompleteButton: Bool

    init(_ attributes: EventCountdownActivityAttributes, _ state: EventCountdownActivityAttributes.State) {
        self.eventName = state.eventName
        self.eventTimeText = state.eventTimeText
        self.eventDate = state.eventDate
        self.startDate = state.startDate
        self.subtitle = state.placeName?.nonEmptyTrimmed ?? state.memo?.nonEmptyTrimmed
        self.showsCompleteButton = attributes.target.isTodo

        let uiColor = UIColor.from(hex: state.tagColorHex) ?? .gray
        self.tagColor = uiColor.asColor
        self.usesDarkGlyph = uiColor.needsDarkGlyphOnBadge
    }
}


private enum Constant {
    /// 흰 글리프를 기본으로 두려는 의도라 `UIColor.isLight`(0.5)보다 높게 잡는다 — 확실히 연한 배경만 검은 글리프로 뒤집힌다.
    static let darkGlyphLuminanceThreshold: CGFloat = 0.75
}


private extension UIColor {

    var needsDarkGlyphOnBadge: Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let luminance: CGFloat = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > Constant.darkGlyphLuminanceThreshold
    }
}


private extension String {

    var nonEmptyTrimmed: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
