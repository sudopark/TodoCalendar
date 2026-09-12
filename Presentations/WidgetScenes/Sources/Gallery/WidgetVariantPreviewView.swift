//
//  WidgetVariantPreviewView.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation


struct WidgetVariantPreviewView: View {

    private enum Constant {
        static let lockScreenPlateOpacity: CGFloat = 0.65
        static let cardBorderWidth: CGFloat = 1
    }

    @Environment(ViewAppearance.self) private var appearance

    private let variant: WidgetVariant
    private let setting: WidgetAppearanceSettings
    private let style: (any WidgetStyleSetting)?

    init(
        variant: WidgetVariant,
        setting: WidgetAppearanceSettings,
        style: (any WidgetStyleSetting)? = nil
    ) {
        self.variant = variant
        self.setting = setting
        self.style = style
    }

    var body: some View {
        // 위젯 뷰는 실제 캔버스 크기로 레이아웃한 뒤 축소해야 폰트·간격이 실물 비율을 지킨다.
        GeometryReader { proxy in
            let scale = variant.canvas.previewScale(fitting: proxy.size)

            scaledContentView(scale)
                .background(plateStyle, in: plateShape(scale))
                .overlay(borderView(scale))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func scaledContentView(_ scale: CGFloat) -> some View {
        let canvas = variant.canvas
        return contentView
            .padding(canvas.contentMargin)
            .frame(width: canvas.size.width, height: canvas.size.height)
            .scaleEffect(scale)
            .frame(width: canvas.size.width * scale, height: canvas.size.height * scale)
            .padding(canvas.previewPlateInset)
    }

    @ViewBuilder
    private var contentView: some View {
        if variant.canvas.isLockScreen {
            // 잠금화면 요소는 벽지 위에 흰 글씨로 얹힌다 — 미리보기는 벽지 대신 어두운 판을 깐다.
            variant.previewView(setting, style: style)
                .environment(\.colorScheme, .dark)
        } else {
            variant.previewView(setting, style: style)
        }
    }

    private var plateStyle: AnyShapeStyle {
        return variant.canvas.isLockScreen
        ? AnyShapeStyle(Color.black.opacity(Constant.lockScreenPlateOpacity))
        : WidgetBackgroundStyle(setting.background).shape
    }

    private func plateShape(_ scale: CGFloat) -> RoundedRectangle {
        return variant.canvas.previewPlateShape(scale)
    }

    @ViewBuilder
    private func borderView(_ scale: CGFloat) -> some View {
        // 라이트 테마에서 흰 카드가 흰 바탕에 묻히지 않게 테두리로 경계를 준다.
        if variant.canvas.isLockScreen == false {
            plateShape(scale)
                .strokeBorder(
                    appearance.colorSet.line.asColor, lineWidth: Constant.cardBorderWidth
                )
        }
    }
}
