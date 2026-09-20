//
//  DDayWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Extensions
import CommonPresentation


// MARK: - 공통 조각

/// 홈은 배경색에서 고른 ColorSet 을, 잠금화면은 시스템 계층 색을 넘긴다 — 한 레이아웃을 둘이 쓴다.
private struct DDayTitleView: View {

    private let model: DDayWidgetViewModel
    private let fontSize: CGFloat
    private let lineLimit: Int
    private let titleStyle: AnyShapeStyle
    private let markStyle: AnyShapeStyle

    init(
        model: DDayWidgetViewModel,
        fontSize: CGFloat,
        lineLimit: Int,
        titleStyle: AnyShapeStyle,
        markStyle: AnyShapeStyle
    ) {
        self.model = model
        self.fontSize = fontSize
        self.lineLimit = lineLimit
        self.titleStyle = titleStyle
        self.markStyle = markStyle
    }

    var body: some View {
        HStack(spacing: 3) {
            if model.isRepeating {
                Image(systemName: "repeat")
                    .font(.system(size: fontSize - 2))
                    .foregroundStyle(markStyle)
            }
            Text(model.eventTitle)
                .font(.system(size: fontSize, weight: .semibold))
                .lineLimit(lineLimit)
                .foregroundStyle(titleStyle)
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

    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.look.colorSet(colorScheme == .light)
    }
    var subTextColor: UIColor {
        return model.look.subTextColor(colorScheme == .light)
    }

    private let model: DDayWidgetViewModel
    public init(model: DDayWidgetViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DDayTitleView(
                model: model, fontSize: 13, lineLimit: 2,
                titleStyle: AnyShapeStyle(colorSet.text0.asColor),
                markStyle: AnyShapeStyle(subTextColor.asColor)
            )

            Spacer(minLength: 0)

            Text(model.ddayText)
                .font(.system(size: 32, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(colorSet.text0.asColor)

            if !model.compactDetailText.isEmpty {
                Text(model.compactDetailText)
                    .font(.system(size: 11))
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .foregroundStyle(subTextColor.asColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


// MARK: - 중형

public struct DDayMediumWidgetView: View {

    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.look.colorSet(colorScheme == .light)
    }
    var subTextColor: UIColor {
        return model.look.subTextColor(colorScheme == .light)
    }

    private let model: DDayWidgetViewModel
    public init(model: DDayWidgetViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DDayTitleView(
                model: model, fontSize: 15, lineLimit: 1,
                titleStyle: AnyShapeStyle(colorSet.text0.asColor),
                markStyle: AnyShapeStyle(subTextColor.asColor)
            )

            Spacer(minLength: 0)

            HStack(alignment: .lastTextBaseline) {
                Text(model.ddayText)
                    .font(.system(size: 36, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(colorSet.text0.asColor)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if !model.dateText.isEmpty {
                        Text(model.dateText)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(subTextColor.asColor)
                    }

                    if !model.detailText.isEmpty {
                        Text(model.detailText)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundStyle(subTextColor.asColor)
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
            DDayTitleView(
                model: model, fontSize: 13, lineLimit: 1,
                titleStyle: AnyShapeStyle(.primary),
                markStyle: AnyShapeStyle(.secondary)
            )

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
