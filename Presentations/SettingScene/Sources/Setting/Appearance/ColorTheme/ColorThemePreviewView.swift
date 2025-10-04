//
//  ColorThemePreviewView.swift
//  SettingScene
//
//  Created by sudo.park on 8/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions
import CommonPresentation


struct ColorThemePreviewView: View {
    
    struct Metric {
        let fontSize: CGFloat
        let circleSize: CGFloat
        let circlePadding: CGFloat
    }
    
    private let model: ColorThemeModel
    private let metric: Metric
    private let colorSet: ColorSet
    @Environment(ViewAppearance.self) private var appearance
    
    init(model: ColorThemeModel, metric: Metric, isSystemDark: Bool) {
        self.model = model
        self.metric = metric
        self.colorSet = model.key.convert(isSystemDarkTheme: isSystemDark)
    }
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(colorSet.holidayOrWeekEndWithAccent.asColor)
                        .frame(width: metric.circleSize, height: metric.circleSize)
                        .padding(.trailing, metric.circlePadding)
                        .padding(.top, metric.circlePadding)
                }
                Spacer()
            }
            VStack {
                Spacer()
                Text("31")
                    .font(.system(size: metric.fontSize))
                    .foregroundStyle(colorSet.text0.asColor)
                Spacer()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorSet.bg0.asColor)
                .shadow(
                    color: appearance.colorSet.text0.withAlphaComponent(0.1).asColor,
                    radius: 8
                )
        )
    }
}

struct ColorThemeItemView: View {
    
    private let model: ColorThemeModel
    @Environment(ViewAppearance.self) private var appearance
    @Environment(\.colorScheme) var colorScheme
    
    init(model: ColorThemeModel) {
        self.model = model
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            ColorThemePreviewView(
                model: model,
                metric: .init(fontSize: 20, circleSize: 8, circlePadding: 8),
                isSystemDark: self.colorScheme == .dark
            )
            .frame(width: 60, height: 60)
         
            Text(model.title)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(
                    model.isSelected 
                    ? appearance.colorSet.primaryBtnText.asColor
                    : appearance.colorSet.weekDayText.asColor
                )
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            model.isSelected 
                            ? appearance.colorSet.primaryBtnBackground.asColor
                            : .clear
                        )
                )
        }
    }
}
