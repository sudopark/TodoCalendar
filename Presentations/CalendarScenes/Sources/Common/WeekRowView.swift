//
//  WeekRowView.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation


private enum Layout {
    static let eventRowHeightWithSpacing: CGFloat = 12
    static let eventTopMargin: CGFloat = 24
    static let eventInterspacing: CGFloat = 2
}

struct WeekRowView: View {
    
    private let week: WeekRowModel
    private let expectSize: CGSize
    private let isCollapsed: Bool
    private let selectedDay: String?
    private let today: String?
    private let focusedMonth: CalendarMonth?
    private let eventsPerDay: AnyPublisher<[[any CalendarEvent]], Never>
    private let eventStack: AnyPublisher<WeekEventStackViewModel, Never>
    private var dayWidth: CGFloat { expectSize.width / 7 }
    
    @Environment(ViewAppearance.self) private var appearance
    
    @State private var eventStackModel: WeekEventStackViewModel = .init(linesStack: [], shouldMarkEventDays: false)
    @State private var eventsPerDays: [[any CalendarEvent]] = []
    
    var daySelected: (DayCellViewModel) -> Void = { _ in }
    var shareEvents: (CalendarShareRangeKind, DayCellViewModel) -> Void = { _, _ in }

    init(
        week: WeekRowModel,
        _ expectSize: CGSize,
        isCollapsed: Bool,
        selectedDay: String?,
        today: String?,
        focusedMonth: CalendarMonth?,
        eventsPerDay: AnyPublisher<[[any CalendarEvent]], Never>,
        eventStack: AnyPublisher<WeekEventStackViewModel, Never>
    ) {
        self.week = week
        self.expectSize = expectSize
        self.isCollapsed = isCollapsed
        self.selectedDay = selectedDay
        self.today = today
        self.focusedMonth = focusedMonth
        self.eventsPerDay = eventsPerDay
        self.eventStack = eventStack
    }
    
    var body: some View {
        self.weekContentView()
            .overlay { self.dayInteractionLayer() }
            .onReceive(self.eventsPerDay.receive(on: RunLoop.main)) {
                self.eventsPerDays = $0
            }
            .onReceive(self.eventStack.receive(on: RunLoop.main)) {
                self.eventStackModel = $0
            }
    }

    private func weekContentView() -> some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                ForEach(week.days, id: \.identifier) { dayView($0) }
            }
            if isCollapsed || appearance.rowHeightOnCalendar == .small {
                eventDotPerDaysView()
                    .transition(.opacity)
            } else {
                eventStackView()
                    .transition(.opacity)
            }
        }
    }

    // 이벤트 바가 날짜 칸 위에 겹쳐 그려져 있어, 탭·롱프레스는 그 위를 덮는 별도 레이어가 받는다
    private func dayInteractionLayer() -> some View {
        HStack(spacing: 0) {
            ForEach(Array(week.days.enumerated()), id: \.element.identifier) { sequence, day in
                Color.clear
                    .frame(width: dayWidth)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appearance.impactIfNeed()
                        self.daySelected(day)
                    }
                    .contextMenu {
                        self.shareEventsMenuItems(day)
                    } preview: {
                        self.dayColumnPreview(at: sequence)
                    }
            }
        }
    }

    @ViewBuilder
    private func shareEventsMenuItems(_ day: DayCellViewModel) -> some View {
        Button {
            self.shareEvents(.day, day)
        } label: {
            Text("calendar::share::this_day".localized())
        }
        Button {
            self.shareEvents(.week, day)
        } label: {
            Text("calendar::share::this_week".localized())
        }
        Button {
            self.shareEvents(.month, day)
        } label: {
            Text("calendar::share::this_month".localized())
        }
    }

    private func dayColumnPreview(at sequence: Int) -> some View {
        self.weekContentView()
            .frame(width: expectSize.width, height: expectSize.height, alignment: .topLeading)
            .offset(x: -self.dayWidth * CGFloat(sequence))
            .frame(width: self.dayWidth, height: expectSize.height, alignment: .leading)
            .clipped()
            .background(self.appearance.colorSet.dayBackground.asColor)
    }

    private func isInFocusedMonth(_ day: DayCellViewModel) -> Bool {
        guard let focusedMonth else { return day.isNotCurrentMonth == false }
        return day.year == focusedMonth.year && day.month == focusedMonth.month
    }

    private func dayView(
        _ day: DayCellViewModel
    ) -> some View {
        let textColor: Color = {
            if day.identifier == self.selectedDay {
                return self.appearance.colorSet.selectedDayText.asColor
            } else {
                return self.appearance.accentCalendarDayColor(day.accentDay).asColor
            }
        }()
        let lineColor: Color = {
            if day.identifier == self.selectedDay {
                return self.appearance.colorSet.selectedDayText.asColor
            } else {
                return self.appearance.colorSet.weekDayText.asColor
            }
        }()
        let backgroundColor: Color = {
            if day.identifier == self.selectedDay {
                return self.appearance.colorSet.selectedDayBackground.asColor
            } else if day.identifier == self.today {
                return self.appearance.colorSet.todayBackground.asColor
            } else {
                return self.appearance.colorSet.dayBackground.asColor
            }
        }()
        let opacity: Double = {
            return day.identifier == self.selectedDay || self.isInFocusedMonth(day)
            ? 1.0 : 0.5
        }()
        let showUnderLine = self.eventStackModel.shouldShowEventLinesDays.contains(day.day)
        return VStack(spacing: 0) {
            Text("\(day.day)")
                .font(self.appearance.fontSet.day.asFont)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.top, spacing: .xsmall)
            if showUnderLine {
                Divider()
                    .background(lineColor)
                    .frame(width: 12, height: 0.5)
            }
            Spacer(minLength: expectSize.height-17)
        }
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.large)
                .fill(backgroundColor)
        )
        .opacity(opacity)
    }
    
    
    private func eventDotPerDaysView() -> some View {
        let grid: [GridItem] = Array(repeating: .init(.flexible(minimum: 30), spacing: 0), count: 7)
        return LazyVGrid(columns: grid) {
            ForEach(0..<7, id: \.self) { seq in
                let day = week.days[safe: seq]
                return eventDotsView(day, eventsPerDays[safe: seq] ?? [])
            }
        }
        .padding(.top, Layout.eventTopMargin*2)
        .frame(height: 4, alignment: .center)
    }
    private func eventDotsView(
        _ day: DayCellViewModel?,
        _ events: [any CalendarEvent]
    ) -> some View {
        
        guard !events.isEmpty
        else {
            return Spacer()
                .asAnyView()
        }
        
        let selectColor: (any CalendarEvent) -> Color = { event in
            switch event.colorSource {
            case let google as GoogleCalendarEventColorSource:
                return self.appearance.googleEventColorOnCalendar(google.colorId, google.calendarId, offColor: { $0.text1 }).asColor
            case let apple as AppleCalendarEventColorSource:
                return self.appearance.appleCalendarColorOnCalendar(apple.calendarId, offColor: { $0.text1 }).asColor
            default:
                return self.appearance.colorOnCalendar(event.eventTagId, offColor: { $0.text1 }).asColor
            }
        }
        let availables: Int = max(0, Int(floor((dayWidth-15)/6)))
        
        let prefix = events.prefix(availables)
        
        func moreView(_ count: Int) -> some View {
            let textColor: Color = if self.selectedDay == day?.identifier {
                appearance.colorSet.eventTextSelected.asColor
            } else {
                appearance.colorSet.eventText.asColor
            }
            return Text("+\(count)")
                .font(appearance.fontSet.size(8).asFont)
                .foregroundStyle(textColor)
        }

        return HStack(spacing: Metric.Spacing.xxsmall) {

            ForEach(0..<prefix.count, id: \.self) { index in
                Circle()
                    .fill(selectColor(prefix[index]))
                    .frame(width: 4, height: 4)
            }
            if prefix.count < events.count {
                moreView(events.count-prefix.count)
            }
        }
        .clipped()
        .asAnyView()
    }
    
    private func eventStackView() -> some View {

        let totalHeight = self.expectSize.height - Layout.eventTopMargin
        let drawableRowCount = Int(totalHeight / Layout.eventRowHeightWithSpacing)
        let maxDrawableEventRowCount = drawableRowCount - 1
        guard maxDrawableEventRowCount > 0 else { return EmptyView().asAnyView() }
        
        let size = if appearance.rowHeightOnCalendar == .large {
            self.eventStackModel.linesStack.count
        } else {
            min(maxDrawableEventRowCount, self.eventStackModel.linesStack.count)
        }
        let bottomView: some View = if appearance.rowHeightOnCalendar == .large {
            Spacer().frame(height: maxDrawableEventRowCount < eventStackModel.linesStack.count ? 10 : 0).asAnyView()
        } else{
            eventMoreViews(eventStackModel.eventMores(with: size)).asAnyView()
        }
        
        return VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
            ForEach(0..<size, id: \.self) {
                return eventRowView(self.eventStackModel.linesStack[$0])
            }
            bottomView
        }
        .padding(.top, Layout.eventTopMargin)
        .asAnyView()
    }
    
    private func eventRowView(_ lines: [EventOnWeek]) -> some View {
        return ZStack(alignment: .leading) {
            ForEach(0..<lines.count, id: \.self) {
                return eventLineView(lines[$0])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func eventLineView(_ line: EventOnWeek) -> some View {
        let offsetX = CGFloat(line.daysSequence.lowerBound-1) * dayWidth + Layout.eventInterspacing
        let width = CGFloat(line.daysSequence.count) * dayWidth - Layout.eventInterspacing
        let lineColor = {
            switch line.colorSource {
            case let google as GoogleCalendarEventColorSource:
                return self.appearance.googleEventColorOnCalendar(google.colorId, google.calendarId).asColor
            case let apple as AppleCalendarEventColorSource:
                return self.appearance.appleCalendarColorOnCalendar(apple.calendarId).asColor
            default:
                return self.appearance.colorOnCalendar(line.event.eventTagId).asColor
            }
        }()
        let background: some View = {
            if line.hasPeriod {
                return RoundedRectangle(cornerRadius: 2).fill(
                    lineColor.opacity(0.5)
                )
                .asAnyView()
            } else {
                return EmptyView().asAnyView()
            }
        }()
        let textColor: Color = {
            return self.selectedDay == line.eventStartDayIdentifierOnWeek
            ? self.appearance.colorSet.eventTextSelected.asColor
            : self.appearance.colorSet.eventText.asColor
        }()
        return HStack(spacing: Metric.Spacing.xxsmall) {
             RoundedRectangle(cornerRadius: Metric.Radius.large)
                 .fill(lineColor)
                 .frame(width: 3, height: 12)
                 .padding(.leading, 1)
             
             Text(line.name)
                .font(self.appearance.eventTextFontOnCalendar().asFont)
                 .foregroundColor(textColor)
                 .lineLimit(1)
        }
        .clipped()
         .frame(width: max(width, 50), alignment: .leading)
         .background(background)
         .offset(x: offsetX)
    }
    
    private func eventMoreViews(_ moreModels: [EventMoreModel]) -> some View {
        let textColor: (EventMoreModel) -> Color = { model in
            let eventIdOnThisWeek = self.week.days[safe: model.daySequence-1]?.identifier
            return self.selectedDay == eventIdOnThisWeek
            ? self.appearance.colorSet.eventTextSelected.asColor
            : self.appearance.colorSet.eventText.asColor
        }
        let offsetX: (EventMoreModel) -> CGFloat = { model in
            return CGFloat(model.daySequence-1) * dayWidth
        }
        return ZStack(alignment: .center) {
            ForEach(moreModels, id: \.daySequence) {
                Text("+\($0.moreCount)")
                    .font(self.appearance.eventTextFontOnCalendar().asFont)
                    .foregroundColor(textColor($0))
                    .frame(width: dayWidth)
                    .offset(x: offsetX($0))
            }
            .padding(.top, spacing: .xxsmall)
        }
    }
}
