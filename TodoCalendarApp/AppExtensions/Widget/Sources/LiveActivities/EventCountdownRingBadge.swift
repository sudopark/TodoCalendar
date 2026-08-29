//
//  EventCountdownRingBadge.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI


/// 색은 배치하는 쪽이 정한다 — 배경 위 대비가 영역마다 달라서다.
struct EventCountdownAppSymbol: View {

    private let diameter: CGFloat
    init(diameter: CGFloat) {
        self.diameter = diameter
    }

    var body: some View {
        Image("app_symbol")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: diameter, height: diameter)
    }
}

/// 잠금화면·아일랜드 확장형 전용 — 잔량은 진행 바가 맡으므로 로고만 노출한다.
struct EventCountdownSymbolBadge: View {

    private let diameter: CGFloat
    init(diameter: CGFloat) {
        self.diameter = diameter
    }

    var body: some View {
        Circle()
            // 아일랜드(검정)·잠금화면(밝은 머티리얼) 양쪽에서 보이려면 적응색이어야 한다.
            .fill(.primary.opacity(0.12))
            .frame(width: diameter, height: diameter)
            .overlay {
                EventCountdownAppSymbol(diameter: diameter * 0.56)
                    .foregroundStyle(.primary)
            }
    }
}

/// compact·minimal 전용 — 진행 바를 놓을 자리가 없어 링이 유일한 잔량 표현이다.
struct EventCountdownRingBadge: View {

    private let model: EventCountdownActivityViewModel
    private let diameter: CGFloat

    init(model: EventCountdownActivityViewModel, diameter: CGFloat) {
        self.model = model
        self.diameter = diameter
    }

    private var symbolDiameter: CGFloat { diameter * 0.58 }

    var body: some View {
        ZStack {
            EventCountdownAppSymbol(diameter: symbolDiameter)
                .foregroundStyle(.secondary)

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
            // 아일랜드(검정)·잠금화면(밝은 머티리얼) 양쪽에서 보이려면 적응색이어야 한다.
            .tint(.primary.opacity(0.55))
            // 시스템 원형 ProgressView는 선 두께를 못 정한다 — 크게 그린 뒤 축소해 상대적으로 얇게 만든다.
            .frame(width: diameter * 2, height: diameter * 2)
            .scaleEffect(0.5)
            .frame(width: diameter, height: diameter)
        }
    }
}
