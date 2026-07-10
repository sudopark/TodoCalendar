//
//  EventTimeTextView.swift
//  EventDetailScene
//
//  Created by sudo.park on 7/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// 상세 화면 4곳(EventDetail·Google·Apple·DoneTodo)이 공유하는 시간 텍스트 라벨(연/일/시각).
// dayLineLimit: Apple 상세는 기존에 lineLimit이 없었음 — 픽셀 불변 보존용 파라미터.
struct EventTimeTextView: View {

    @Environment(ViewAppearance.self) private var appearance

    private let timeText: SelectTimeText
    private let textColor: Color?
    private let isStrikethrough: Bool
    private let dayLineLimit: Int?

    init(
        _ timeText: SelectTimeText,
        textColor: Color? = nil,
        isStrikethrough: Bool = false,
        dayLineLimit: Int? = 1
    ) {
        self.timeText = timeText
        self.textColor = textColor
        self.isStrikethrough = isStrikethrough
        self.dayLineLimit = dayLineLimit
    }

    var body: some View {
        let color = self.textColor ?? self.appearance.colorSet.text0.asColor
        return VStack(alignment: .leading) {

            if let year = self.timeText.year {
                Text(year)
                    .strikethrough(self.isStrikethrough)
                    .font(self.appearance.fontSet.size(14).asFont)
                    .foregroundStyle(color)
            }

            Text(self.timeText.day)
                .lineLimit(self.dayLineLimit)
                .strikethrough(self.isStrikethrough)
                .font(self.appearance.fontSet.size(14).asFont)
                .foregroundStyle(color)

            if let time = self.timeText.time {
                Text(time)
                    .strikethrough(self.isStrikethrough)
                    .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                    .foregroundStyle(color)
            }
        }
    }
}
