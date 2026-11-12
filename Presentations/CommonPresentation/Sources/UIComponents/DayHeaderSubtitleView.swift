//
//  DayHeaderSubtitleView.swift
//  CommonPresentation
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CalendarDomainInterface


public struct DayHeaderSubtitleView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let lunarDateText: String?
    private let rokuyo: Rokuyo?
    private let holidayName: String?
    private let holidayColor: Color

    public init(
        lunarDateText: String?,
        rokuyo: Rokuyo?,
        holidayName: String?,
        holidayColor: Color
    ) {
        self.lunarDateText = lunarDateText
        self.rokuyo = rokuyo
        self.holidayName = holidayName
        self.holidayColor = holidayColor
    }

    public var body: some View {
        if self.lunarDateText != nil || self.rokuyo != nil || self.holidayName != nil {
            HStack(alignment: .top, spacing: Metric.Spacing.small) {
                if let lunarDateText {
                    Text(lunarDateText)
                        .font(self.appearance.eventSubNormalTextFontOnList().asFont)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                        .lineLimit(1)
                }

                if let rokuyo {
                    RokuyoLabelView(rokuyo, font: self.appearance.eventSubNormalTextFontOnList().asFont)
                }

                if let holidayName {
                    Text(holidayName)
                        .font(self.appearance.eventSubNormalTextFontOnList().asFont)
                        .foregroundStyle(self.holidayColor)
                }
            }
        }
    }
}
