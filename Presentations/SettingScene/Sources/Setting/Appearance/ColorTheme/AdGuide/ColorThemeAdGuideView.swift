//
//  ColorThemeAdGuideView.swift
//  SettingScene
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import CommonPresentation


enum ColorThemeAdGuidePurpose {
    case applyTheme
    case createTheme

    fileprivate var titleKey: String {
        switch self {
        case .applyTheme: return "setting.appearance.calendar.colorTheme.adGuide::apply::title"
        case .createTheme: return "setting.appearance.calendar.colorTheme.adGuide::create::title"
        }
    }

    fileprivate var messageKey: String {
        switch self {
        case .applyTheme: return "setting.appearance.calendar.colorTheme.adGuide::apply::message"
        case .createTheme: return "setting.appearance.calendar.colorTheme.adGuide::create::message"
        }
    }
}


struct ColorThemeAdGuideView: View {

    private let purpose: ColorThemeAdGuidePurpose
    private let licenseDays: Int
    private let appearance: ViewAppearance
    var onWatchAd: () -> Void = { }
    var onShowPlans: () -> Void = { }
    var onClose: () -> Void = { }

    init(purpose: ColorThemeAdGuidePurpose, licenseDays: Int, appearance: ViewAppearance) {
        self.purpose = purpose
        self.licenseDays = licenseDays
        self.appearance = appearance
    }

    var body: some View {
        ColorThemeAdGuideContentView(purpose: self.purpose, licenseDays: self.licenseDays)
            .eventHandler(\.onWatchAd, onWatchAd)
            .eventHandler(\.onShowPlans, onShowPlans)
            .eventHandler(\.onClose, onClose)
            .environment(appearance)
    }
}


private struct ColorThemeAdGuideContentView: View {

    @Environment(ViewAppearance.self) private var appearance
    let purpose: ColorThemeAdGuidePurpose
    let licenseDays: Int
    var onWatchAd: () -> Void = { }
    var onShowPlans: () -> Void = { }
    var onClose: () -> Void = { }

    var body: some View {
        BottomSlideView {
            VStack(alignment: .leading, spacing: Metric.Spacing.large) {

                HStack(spacing: Metric.Spacing.small) {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(appearance.colorSet.accentWarn.asColor)
                    Text(purpose.titleKey.localized())
                }
                .font(appearance.fontSet.bigBold.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .padding(.top, spacing: .regular)

                VStack(alignment: .leading, spacing: Metric.Spacing.small) {
                    Text(purpose.messageKey.localized(with: licenseDays))
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                    Text("setting.appearance.calendar.colorTheme.adGuide::freeThemes::message".localized())
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                }

                planRow

                VStack(spacing: Metric.Spacing.xsmall) {
                    ConfirmButton(
                        title: "setting.appearance.calendar.colorTheme.adGuide::watchAd::button"
                            .localized(with: licenseDays)
                    )
                    .eventHandler(\.onTap, onWatchAd)

                    Text("common.cancel".localized())
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, spacing: .regular)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onClose)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .eventHandler(\.outsideTap, onClose)
    }

    private var planRow: some View {
        HStack(spacing: Metric.Spacing.small) {
            Text("setting.appearance.calendar.colorTheme.adGuide::plan::message".localized())
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .multilineTextAlignment(.leading)
            Spacer(minLength: Metric.Spacing.small)
            HStack(spacing: Metric.Spacing.xxsmall) {
                Text("setting.appearance.calendar.colorTheme.adGuide::plan::button".localized())
                Image(systemName: "chevron.right")
            }
            .font(appearance.fontSet.subNormalWithBold.asFont)
            .foregroundStyle(appearance.colorSet.accent.asColor)
        }
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(appearance.colorSet.bg1.asColor)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onShowPlans)
    }
}


final class ColorThemeAdGuideViewController: UIHostingController<ColorThemeAdGuideView> {

    init(guideView: ColorThemeAdGuideView) {
        super.init(rootView: guideView)
        self.view.backgroundColor = .clear
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
