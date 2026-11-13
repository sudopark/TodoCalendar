//
//  ExternalCalendarEventTagCellView.swift
//  SettingScene
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import EventDomainInterface
import ExternalCalendarDomainInterface
import CommonPresentation


struct ExternalCalendarEventTagCellView: View {

    @Environment(ViewAppearance.self) private var appearance
    private let cellViewModel: ExternalCalendarEventTagCellViewModel
    var onTap: () -> Void = { }

    init(_ cellViewModel: ExternalCalendarEventTagCellViewModel) {
        self.cellViewModel = cellViewModel
    }

    var body: some View {
        HStack {
            EventTagColorView(self.colorSource) { color in
                Image(systemName: cellViewModel.isOn ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(color)
                    .font(.title3)
            }
                .animation(.easeIn, value: cellViewModel.isOn)
                .onTapGesture {
                    self.appearance.impactIfNeed()
                    self.onTap()
                }

            VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
                Text(cellViewModel.name)
                    .lineLimit(1)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                if let email = cellViewModel.accountEmail, !email.isEmpty {
                    Text(email)
                        .lineLimit(1)
                        .font(self.appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                }
            }

            Spacer()
        }
        .padding(.horizontal, spacing: .regular)
        .padding(.vertical, spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }

    private var colorSource: any EventTagColorSource {
        switch cellViewModel.id {
        case .externalCalendar(AppleCalendarService.id, let calendarId):
            return AppleCalendarEventColorSource(calendarId: calendarId)
        case .externalCalendar(_, let calendarId):
            return GoogleCalendarEventColorSource(calendarId: calendarId, colorId: nil)
        default:
            return cellViewModel.id
        }
    }
}
