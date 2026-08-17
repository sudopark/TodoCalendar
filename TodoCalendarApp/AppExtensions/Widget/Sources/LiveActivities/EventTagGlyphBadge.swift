//
//  EventTagGlyphBadge.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI


struct EventTagGlyphBadge: View {

    private let model: EventCountdownActivityViewModel
    private let diameter: CGFloat

    init(model: EventCountdownActivityViewModel, diameter: CGFloat) {
        self.model = model
        self.diameter = diameter
    }

    private var circleDiameter: CGFloat { diameter * 0.76 }
    private var glyphDiameter: CGFloat { circleDiameter * 0.744 }

    var body: some View {
        ZStack {
            Circle()
                .fill(model.tagColor)
                .frame(width: circleDiameter, height: circleDiameter)

            Image("app_symbol")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: glyphDiameter, height: glyphDiameter)
                .foregroundStyle(model.usesDarkGlyph ? .black : .white)

            remainRing
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private var remainRing: some View {
        // 만료 후에는 timerInterval range가 역전돼 트랩하므로 링 자체를 그리지 않는다.
        if model.eventDate > .now, model.startDate < model.eventDate {
            ProgressView(timerInterval: model.startDate...model.eventDate, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            // 링은 원 바깥이라 바탕이 태그색이 아닌 표면색이다 — 아일랜드(검정)·잠금화면(밝은 머티리얼) 양쪽에서 보이려면 적응색이어야 한다.
            .tint(.primary.opacity(0.55))
            // 시스템 원형 ProgressView는 선 두께를 못 정한다 — 크게 그린 뒤 축소해 상대적으로 얇게 만든다.
            .frame(width: diameter * 2, height: diameter * 2)
            .scaleEffect(0.5)
            .frame(width: diameter, height: diameter)
        }
    }
}
