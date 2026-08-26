//
//  LiveActivityBadgeView.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/26/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// MARK: - LiveActivityBadgeView

struct LiveActivityBadgeView: View {

    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        HStack(spacing: Metric.Spacing.small) {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(self.appearance.colorSet.accent.asColor)

            Text("calendar::event::more_action:live_activity:showing".localized())
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(self.appearance.fontSet.normal.asFont)

            Spacer()
        }
    }
}
