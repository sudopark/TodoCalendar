//
//  DDayWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Extensions


// MARK: - 공통 조각

private struct DDayTitleView: View {

    private let model: DDayWidgetViewModel
    private let fontSize: CGFloat
    private let lineLimit: Int

    init(model: DDayWidgetViewModel, fontSize: CGFloat, lineLimit: Int) {
        self.model = model
        self.fontSize = fontSize
        self.lineLimit = lineLimit
    }

    var body: some View {
        HStack(spacing: 3) {
            if model.isRepeating {
                Image(systemName: "repeat")
                    .font(.system(size: fontSize - 2))
                    .foregroundStyle(.secondary)
            }
            Text(model.eventTitle)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(lineLimit)
                .foregroundStyle(.primary)
        }
    }
}

private extension DDayWidgetViewModel {

    /// 소형 하단 한 줄 — "매주 월 · 3/15 오전 7:00". 빈 조각은 뺀다.
    var compactDetailText: String {
        return [self.repeatText, self.dateText, self.timeText]
            .joinedNonEmpty(separator: " · ")
    }

    /// 중형 우측 둘째 줄 — "오전 7:00 · 매주 월".
    var detailText: String {
        return [self.timeText, self.repeatText]
            .joinedNonEmpty(separator: " · ")
    }
}


// MARK: - 소형

public struct DDaySmallWidgetView: View {

    private let model: DDayWidgetViewModel
    public init(model: DDayWidgetViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DDayTitleView(model: model, fontSize: 13, lineLimit: 2)

            Spacer(minLength: 0)

            Text(model.ddayText)
                .font(.system(size: 32, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if !model.compactDetailText.isEmpty {
                Text(model.compactDetailText)
                    .font(.system(size: 11))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - 중형

public struct DDayMediumWidgetView: View {

    private let model: DDayWidgetViewModel
    public init(model: DDayWidgetViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DDayTitleView(model: model, fontSize: 15, lineLimit: 1)

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline) {
                Text(model.ddayText)
                    .font(.system(size: 36, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if !model.dateText.isEmpty {
                        Text(model.dateText)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }

                    if !model.detailText.isEmpty {
                        Text(model.detailText)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - 잠금화면

/// 잠금화면은 시스템이 단색 렌더링을 적용하므로 색을 직접 지정하지 않는다.
/// 시스템 배경(`AccessoryWidgetBackground`)은 WidgetKit 타입이라 확장의 엔트리 뷰가 씌운다.
public struct DDayCircularWidgetView: View {

    private let model: DDayWidgetViewModel
    public init(model: DDayWidgetViewModel) {
        self.model = model
    }

    public var body: some View {
        Text(model.ddayText)
            .font(.system(size: 17, weight: .bold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(2)
    }
}

public struct DDayRectangularWidgetView: View {

    private let model: DDayWidgetViewModel
    public init(model: DDayWidgetViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            DDayTitleView(model: model, fontSize: 13, lineLimit: 1)

            Text(model.ddayText)
                .font(.system(size: 18, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if !model.dateText.isEmpty {
                Text(model.dateText)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct DDayInlineWidgetView: View {

    private let model: DDayWidgetViewModel
    public init(model: DDayWidgetViewModel) {
        self.model = model
    }

    public var body: some View {
        Text(model.lockScreenInlineText)
    }
}
