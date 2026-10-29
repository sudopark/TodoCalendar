//
//  TrackingGuideView.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Extensions
import CommonPresentation


struct TrackingGuideView: View {

    private let appearance: ViewAppearance
    var onContinue: () -> Void = { }
    var onDecline: () -> Void = { }

    init(appearance: ViewAppearance) {
        self.appearance = appearance
    }

    var body: some View {
        TrackingGuideContentView()
            .eventHandler(\.onContinue, onContinue)
            .eventHandler(\.onDecline, onDecline)
            .environment(self.appearance)
    }
}


private struct TrackingGuideContentView: View {

    @Environment(ViewAppearance.self) private var appearance
    var onContinue: () -> Void = { }
    var onDecline: () -> Void = { }

    var body: some View {
        BottomSlideView {
            VStack(alignment: .leading, spacing: Metric.Spacing.xlarge) {

                Text("ad.trackingGuide::title".localized())
                    .font(appearance.fontSet.bigBold.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                    .padding(.top, spacing: .regular)

                VStack(alignment: .leading, spacing: Metric.Spacing.regular) {
                    Text("ad.trackingGuide::message1".localized())
                    Text("ad.trackingGuide::message2".localized())
                }
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)

                VStack(spacing: Metric.Spacing.small) {
                    ConfirmButton(title: "ad.trackingGuide::continue::button".localized())
                        .eventHandler(\.onTap, onContinue)

                    ConfirmButton(
                        title: "common.close".localized(),
                        textColor: appearance.colorSet.secondaryBtnText.asColor,
                        backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                    )
                    .eventHandler(\.onTap, onDecline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .eventHandler(\.outsideTap, onDecline)
    }
}
