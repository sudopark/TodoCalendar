//
//  AIAgentNotificationPermissionNoticeView.swift
//  AIAgentScene
//
//  Created by sudo.park on 8/25/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Extensions
import CommonPresentation


struct AIAgentNotificationPermissionNoticeView: View {

    @Environment(ViewAppearance.self) private var appearance
    var onTap: () -> Void = { }

    var body: some View {
        HStack(spacing: Metric.Spacing.xsmall) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)

            Text("aiAgent::notificationPermissionDenied::message".localized())
                .font(self.appearance.fontSet.size(12).asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
        .padding(spacing: .small)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            self.onTap()
        }
    }
}
