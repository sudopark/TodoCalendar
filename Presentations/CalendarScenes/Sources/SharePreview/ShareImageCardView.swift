//
//  ShareImageCardView.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation
import Extensions


// MARK: - ShareImageCardView

struct ShareImageCardView: View {

    @Environment(ViewAppearance.self) private var appearance

    let headerText: String
    let content: ShareImageContentModel
    let cardWidth: CGFloat
    var lineTapped: (String) -> Void = { _ in }

    private var contentWidth: CGFloat {
        max(self.cardWidth - Metric.Spacing.regular * 2, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.regular) {
            self.headerView
            self.contentView
            self.watermarkView
        }
        .padding(spacing: .regular)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(self.appearance.colorSet.bg0.asColor)
        )
        .frame(width: self.cardWidth)
    }

    private var headerView: some View {
        Text(self.headerText)
            .font(self.appearance.fontSet.size(18, weight: .bold).asFont)
            .foregroundStyle(self.appearance.colorSet.text0.asColor)
    }

    @ViewBuilder
    private var contentView: some View {
        switch self.content {
        case .list(let sections):
            ShareImageListView(sections: sections, lineTapped: self.lineTapped)
        case .monthGrid(let grid):
            ShareImageMonthGridView(grid: grid, dayWidth: self.contentWidth / 7, lineTapped: self.lineTapped)
        }
    }

    private var watermarkView: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
            Rectangle()
                .fill(self.appearance.colorSet.line.asColor)
                .frame(height: 1)
            HStack(spacing: Metric.Spacing.xsmall) {
                Image("app_symbol")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("TodoCalendar")
                    .font(self.appearance.fontSet.subNormal.asFont)
            }
            .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
    }
}


// MARK: - ShareImageListView

private struct ShareImageListView: View {

    @Environment(ViewAppearance.self) private var appearance

    let sections: [ShareImageListSection]
    let lineTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            ForEach(self.sections) { section in
                self.sectionView(section)
            }
        }
    }

    private func sectionView(_ section: ShareImageListSection) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            if let dayHeaderText = section.dayHeaderText {
                Text(dayHeaderText)
                    .font(self.appearance.fontSet.size(15, weight: .semibold).asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                    .padding(.top, spacing: .small)
            }
            ForEach(section.lines) { line in
                ShareImageListLineView(line: line, lineTapped: self.lineTapped)
            }
        }
    }
}


// MARK: - ShareImageListLineView

private struct ShareImageListLineView: View {

    @Environment(ViewAppearance.self) private var appearance
    let line: ShareImageListLine
    let lineTapped: (String) -> Void

    var body: some View {
        HStack(spacing: Metric.Spacing.small) {
            self.timeColumnView
                .frame(width: 52)

            EventTagColorView(self.line.cellViewModel.colorSource) { color in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 6)
            }

            self.bodyColumnView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, spacing: .xsmall).padding(.horizontal, spacing: .small)
        .frame(minHeight: Constant.listLineMinHeight)
        .backgroundAsRoundedRectForEventList(self.appearance)
        .opacity(self.line.isExcluded ? Constant.dimmedOpacity : 1)
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.lineTapped(self.line.eventId)
        }
    }

    @ViewBuilder
    private var timeColumnView: some View {
        switch self.line.cellViewModel.periodText {
        case .singleText(let text):
            self.singleTimeText(text)
        case .doubleText(let top, let bottom):
            self.doubleTimeText(top, bottom)
        default:
            EmptyView()
        }
    }

    private func pmOrAmView(_ text: String) -> some View {
        Text(text)
            .minimumScaleFactor(0.7)
            .font(self.appearance.fontSet.size(8+self.appearance.eventTextAdditionalSize).asFont)
            .foregroundStyle(self.appearance.colorSet.text0.asColor)
    }

    private func singleTimeText(_ text: EventTimeText) -> some View {
        VStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline, spacing: Metric.Spacing.xxsmall) {
                Text(text.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(self.appearance.fontSet.size(15+self.appearance.eventTextAdditionalSize, weight: .regular).asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)

                if let amPm = text.pmOram {
                    self.pmOrAmView(amPm)
                }
            }
        }
    }

    private func doubleTimeText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
        VStack(alignment: .center, spacing: Metric.Spacing.xxsmall) {
            HStack(alignment: .firstTextBaseline, spacing: Metric.Spacing.xxsmall) {
                Text(top.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(self.appearance.fontSet.size(15+self.appearance.eventTextAdditionalSize, weight: .regular).asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)

                if let amPm = top.pmOram {
                    self.pmOrAmView(amPm)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: Metric.Spacing.xxsmall) {
                Text(bottom.text)
                    .minimumScaleFactor(0.7)
                    .font(self.appearance.fontSet.size(14+self.appearance.eventTextAdditionalSize).asFont)
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)

                if let amPm = bottom.pmOram {
                    self.pmOrAmView(amPm)
                }
            }
        }
    }

    private var bodyColumnView: some View {
        HStack(spacing: Metric.Spacing.small) {
            VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
                Text(self.line.cellViewModel.name)
                    .minimumScaleFactor(0.7)
                    .font(self.appearance.eventTextFontOnList(isForemost: self.line.cellViewModel.isForemost).asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)

                if let periodDescription = self.line.cellViewModel.periodDescription {
                    Text(periodDescription)
                        .minimumScaleFactor(0.7)
                        .font(self.appearance.fontSet.size(13+self.appearance.eventTextAdditionalSize).asFont)
                        .foregroundStyle(self.appearance.colorSet.text1.asColor)
                }
            }
            Spacer(minLength: 0)
        }
    }
}


// MARK: - ShareImageMonthGridView

private struct ShareImageMonthGridView: View {

    @Environment(ViewAppearance.self) private var appearance
    let grid: ShareImageMonthGrid
    let dayWidth: CGFloat
    let lineTapped: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
            self.weekDaysHeaderView
            ForEach(self.grid.weeks) { week in
                self.weekRowView(week)
            }
        }
    }

    private var weekDaysHeaderView: some View {
        HStack(spacing: 0) {
            ForEach(self.grid.weekDays, id: \.identifier) { model in
                Text(model.symbol)
                    .font(self.appearance.fontSet.weekday.asFont)
                    .foregroundStyle(self.weekdayColor(model).asColor)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayColor(_ model: WeekDayModel) -> UIColor {
        let accent: AccentDays? = model.isSunday ? .sunday : model.isSaturday ? .saturday : nil
        return self.appearance.accentCalendarDayColor(accent)
    }

    private func weekRowView(_ week: ShareImageMonthWeek) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
            self.dayNumbersRowView(week.row)
            self.eventStacksView(week)
        }
        .frame(maxWidth: .infinity, minHeight: Constant.monthWeekRowMinHeight, alignment: .top)
    }

    private func dayNumbersRowView(_ row: WeekRowModel) -> some View {
        HStack(spacing: 0) {
            ForEach(row.days, id: \.identifier) { day in
                Text("\(day.day)")
                    .font(self.appearance.fontSet.day.asFont)
                    .foregroundStyle(self.appearance.accentCalendarDayColor(day.accentDay).asColor)
                    .opacity(day.isNotCurrentMonth ? Constant.dimmedOpacity : 1)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func eventStacksView(_ week: ShareImageMonthWeek) -> some View {
        VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
            ForEach(0..<week.eventStacks.count, id: \.self) { rowIndex in
                self.eventRowView(week.eventStacks[rowIndex])
            }
        }
    }

    private func eventRowView(_ lines: [EventOnWeek]) -> some View {
        ZStack(alignment: .leading) {
            ForEach(0..<lines.count, id: \.self) { index in
                self.eventLineView(lines[index])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func eventLineView(_ line: EventOnWeek) -> some View {
        let offsetX = CGFloat(line.daysSequence.lowerBound-1) * self.dayWidth + 1
        let width = CGFloat(line.daysSequence.count) * self.dayWidth - 1
        let color = self.lineColor(line)
        let isExcluded = self.grid.excludedEventIds.contains(line.eventId)
        let background: some View = Group {
            if line.hasPeriod {
                RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.5))
            } else {
                EmptyView()
            }
        }
        return HStack(spacing: Metric.Spacing.xxsmall) {
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(color)
                .frame(width: 3, height: 12)
                .padding(.leading, 1)

            Text(line.name)
                .font(self.appearance.eventTextFontOnCalendar().asFont)
                .foregroundStyle(self.appearance.colorSet.eventText.asColor)
                .lineLimit(1)
        }
        .clipped()
        .frame(width: max(width, 50), alignment: .leading)
        .background(background)
        .offset(x: offsetX)
        .opacity(isExcluded ? Constant.dimmedOpacity : 1)
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.lineTapped(line.eventId)
        }
    }

    private func lineColor(_ line: EventOnWeek) -> Color {
        switch line.colorSource {
        case let google as GoogleCalendarEventColorSource:
            return self.appearance.googleEventColorOnCalendar(google.colorId, google.calendarId).asColor
        case let apple as AppleCalendarEventColorSource:
            return self.appearance.appleCalendarColorOnCalendar(apple.calendarId).asColor
        default:
            return self.appearance.colorOnCalendar(line.event.eventTagId).asColor
        }
    }
}


// MARK: - Constant

private enum Constant {
    static let dimmedOpacity: Double = 0.3
    static let listLineMinHeight: CGFloat = 44
    static let monthWeekRowMinHeight: CGFloat = 60
}
