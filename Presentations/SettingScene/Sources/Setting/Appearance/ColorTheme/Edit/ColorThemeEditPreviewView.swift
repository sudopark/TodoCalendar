//
//  ColorThemeEditPreviewView.swift
//  SettingScene
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation
import EventDomainInterface
import ExternalCalendarDomainInterface


// MARK: - ColorThemeEditPreviewView

struct ColorThemeEditPreviewView: View {

    private let model: CalendarAppearanceModel
    private let colorSet: any ColorSet
    @Environment(ViewAppearance.self) private var appearance

    private let visibleWeekCount = 3
    private let todayNumber = 3
    private let selectedDayNumber = 9

    init(model: CalendarAppearanceModel, colorSet: any ColorSet) {
        self.model = model
        self.colorSet = colorSet
    }

    var body: some View {
        VStack(spacing: Metric.Spacing.small) {
            self.headerView
            self.calendarView
            self.eventCardView
            self.aiChipView
        }
        .padding(.vertical, spacing: .regular)
        .padding(.horizontal, spacing: .large)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(self.colorSet.bg0.asColor)
                .shadow(
                    color: self.colorSet.text0.withAlphaComponent(0.4).asColor,
                    radius: 10
                )
        )
        .padding(.horizontal, spacing: .xlarge)
    }

    private var headerView: some View {
        HStack {
            Text("setting.appearance.calendar.samplemonth::march".localized())
                .font(self.appearance.fontSet.size(12, weight: .semibold).asFont)
                .foregroundStyle(self.colorSet.text0.asColor)
            Spacer()
            self.capsule(
                Text("setting.appearance.calendar.colorTheme.edit::preview::addEvent".localized()),
                background: self.colorSet.accent
            )
        }
    }

    private var calendarView: some View {
        Grid(horizontalSpacing: Metric.Spacing.xxsmall, verticalSpacing: Metric.Spacing.xsmall) {
            GridRow {
                ForEach(self.model.weekDays, id: \.rawValue) { day in
                    self.dayLabel(day.veryShortText, isWeekEnd: day == .sunday || day == .saturday)
                }
            }
            ForEach(0..<min(self.visibleWeekCount, self.model.weeks.count), id: \.self) { index in
                GridRow {
                    ForEach(0..<self.model.weeks[index].count, id: \.self) { dayIndex in
                        self.dayCell(self.model.weeks[index][dayIndex])
                    }
                }
            }
        }
    }

    private func dayCell(_ day: CalendarAppearanceModel.DayModel?) -> some View {
        let isSelected = day?.number == self.selectedDayNumber
        let background: UIColor = {
            if isSelected { return self.colorSet.selectedDayBackground }
            if day?.number == self.todayNumber { return self.colorSet.todayBackground }
            return .clear
        }()
        return self.dayLabel(
            day.map { "\($0.number)" } ?? "",
            isWeekEnd: day?.accent != nil,
            isSelected: isSelected,
            background: background
        )
    }

    // 강조 요일 설정이 꺼져도 휴일·주말 입력이 칠하는 자리가 보여야 한다
    private func dayLabel(
        _ text: String,
        isWeekEnd: Bool,
        isSelected: Bool = false,
        background: UIColor = .clear
    ) -> some View {
        let textColor: UIColor = {
            if isSelected { return self.colorSet.selectedDayText }
            return isWeekEnd ? self.colorSet.holidayOrWeekEndWithAccent : self.colorSet.weekDayText
        }()
        return Text(text)
            .font(self.appearance.fontSet.size(10).asFont)
            .foregroundStyle(textColor.asColor)
            .frame(maxWidth: .infinity)
            .frame(height: 17)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(background.asColor)
            )
    }

    private var eventCardView: some View {
        VStack(spacing: 0) {
            self.eventRow(
                "setting.appearance.calendar.colorTheme.edit::preview::event1".localized(),
                time: "10:00",
                tag: .default
            )
            Rectangle()
                .fill(self.colorSet.line.asColor)
                .frame(height: 1)
            self.eventRow(
                "setting.appearance.calendar.colorTheme.edit::preview::event2".localized(),
                time: "18:00",
                tag: .holiday
            )
        }
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.chip)
                .fill(self.colorSet.bg1.asColor)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metric.Radius.chip))
    }

    private func eventRow(_ title: String, time: String, tag: EventTagId) -> some View {
        HStack(spacing: Metric.Spacing.small) {
            Circle()
                .fill(self.appearance.color(tag).asColor)
                .frame(width: 6, height: 6)
            Text(title)
                .font(self.appearance.fontSet.size(11).asFont)
                .foregroundStyle(self.colorSet.text0.asColor)
            Spacer()
            Text(time)
                .font(self.appearance.fontSet.size(10).asFont)
                .foregroundStyle(self.colorSet.text1.asColor)
        }
        .padding(.vertical, spacing: .small)
        .padding(.horizontal, spacing: .small)
    }

    private var aiChipView: some View {
        self.capsule(
            HStack(spacing: Metric.Spacing.xxsmall) {
                Image(systemName: "sparkles")
                Text("AI")
            },
            background: self.colorSet.accentAI
        )
    }

    private func capsule<Label: View>(_ label: Label, background: UIColor) -> some View {
        label
            .font(self.appearance.fontSet.size(10, weight: .semibold).asFont)
            .foregroundStyle(self.colorSet.primaryBtnText.asColor)
            .padding(.vertical, spacing: .xxsmall)
            .padding(.horizontal, spacing: .small)
            .background(Capsule().fill(background.asColor))
    }
}
