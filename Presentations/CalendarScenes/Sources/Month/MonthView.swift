//
//  MonthView.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/03.
//

import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation

final class MonthViewState: ObservableObject {
    
    @Published fileprivate var weekDays: [WeekDayModel] = []
    @Published fileprivate var weeks: [WeekRowModel] = []
    @Published fileprivate var selectedDay: String?
    @Published fileprivate var today: String?
    var eventStacks: (String) -> AnyPublisher<WeekEventStackViewModel, Never> = { _ in
        Empty().eraseToAnyPublisher()
    }
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any MonthViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true
        
        self.eventStacks = viewModel.eventStack(at:)
        
        viewModel.weekDays
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] days in
                self?.weekDays = days
            })
            .store(in: &self.cancellables)
        
        viewModel.weekModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.weeks = models
            })
            .store(in: &self.cancellables)
        
        viewModel.currentSelectDayIdentifier
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] identifier in
                self?.selectedDay = identifier
            })
            .store(in: &self.cancellables)
        
        viewModel.todayIdentifier
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] identifier in
                self?.today = identifier
            })
            .store(in: &self.cancellables)
    }
}

final class MonthViewEventHandler: ObservableObject {
    var daySelected: (DayCellViewModel) -> Void = { _ in }
    
    func bind(_ viewModel: any MonthViewModel) {
        self.daySelected = viewModel.select(_:)
    }
}

struct MonthContainerView: View {
    
    @StateObject private var state: MonthViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: MonthViewEventHandler
    
    var stateBinding: (MonthViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandler: MonthViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
    }
    
    var body: some View {
        return MonthView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandler)
    }
}


private enum Metric {
    static let dayMinHeight: CGFloat = 80
    static let dayMaxHeight: CGFloat = 100
    static let eventRowHeightWithSpacing: CGFloat = 12
    static let eventTopMargin: CGFloat = 24
    static let eventInterspacing: CGFloat = 2
}

struct MonthView: View {
    
    @EnvironmentObject private var state: MonthViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandler: MonthViewEventHandler
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            if state.weeks.isEmpty {
                self.emptyGridView()
            } else {
                self.gridWeeksView()
            }
        }
        .padding([.leading, .trailing], 8)
        .background(self.appearance.colorSet.dayBackground.asColor)
    }
    
    private var headerView: some View {
        let textColor: (WeekDayModel) -> Color = {
            let accent: AccentDays? = $0.isSunday ? .sunday : $0.isSaturday ? .saturday : nil
            return appearance.accentCalendarDayColor(accent).asColor
        }
        return HStack {
            ForEach(self.state.weekDays, id: \.identifier) { weekDay in
                Text(weekDay.symbol)
                    .font(self.appearance.fontSet.weekday.asFont)
                    .foregroundColor(textColor(weekDay))
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func gridWeeksView() -> some View {
        let expectSize = CGSize(
            width: UIScreen.main.bounds.width - 16,
            height: 75
        )
        return VStack(spacing: 0) {
            ForEach(self.state.weeks, id: \.id) {
                WeekRowView(week: $0, expectSize)
                    .eventHandler(\.daySelected, eventHandler.daySelected)
                    .environmentObject(state)
                    .environmentObject(appearance)
            }
        }
    }
    
    private func emptyGridView() -> some View {
        Rectangle()
            .fill(appearance.colorSet.dayBackground.asColor)
            .frame(height: 500)
    }
}

private struct WeekRowView: View {
    
    private let week: WeekRowModel
    private let expectSize: CGSize
    private var dayWidth: CGFloat { expectSize.width / 7 }
    
    @EnvironmentObject private var state: MonthViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    @State private var eventStackModel: WeekEventStackViewModel = .init(linesStack: [], shouldMarkEventDays: false)
    
    fileprivate var daySelected: (DayCellViewModel) -> Void = { _ in }
    
    init(
        week: WeekRowModel,
        _ expectSize: CGSize
    ) {
        self.week = week
        self.expectSize = expectSize
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                ForEach(week.days, id: \.identifier) { dayView($0) }
            }
            eventStackView()
        }
        .onReceive(state.eventStacks(week.id).receive(on: RunLoop.main)) {
            self.eventStackModel = $0
        }
    }
    
    private func dayView(
        _ day: DayCellViewModel
    ) -> some View {
        let textColor: Color = {
            if day.identifier == self.state.selectedDay {
                return self.appearance.colorSet.selectedDayText.asColor
            } else {
                return self.appearance.accentCalendarDayColor(day.accentDay).asColor
            }
        }()
        let lineColor: Color = {
            if day.identifier == self.state.selectedDay {
                return self.appearance.colorSet.selectedDayText.asColor
            } else {
                return self.appearance.colorSet.weekDayText.asColor
            }
        }()
        let backgroundColor: Color = {
            if day.identifier == self.state.selectedDay {
                return self.appearance.colorSet.selectedDayBackground.asColor
            } else if day.identifier == self.state.today {
                return self.appearance.colorSet.todayBackground.asColor
            } else {
                return self.appearance.colorSet.dayBackground.asColor
            }
        }()
        let opacity: Double = {
            return day.identifier == self.state.selectedDay || day.isNotCurrentMonth == false
            ? 1.0 : 0.5
        }()
        let showUnderLine = self.eventStackModel.shouldShowEventLinesDays.contains(day.day)
        return VStack(spacing: 0) {
            Text("\(day.day)")
                .font(self.appearance.fontSet.day.asFont)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            if showUnderLine {
                Divider()
                    .background(lineColor)
                    .frame(width: 12, height: 0.5)
            }
            Spacer(minLength: expectSize.height-17)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .opacity(opacity)
        .onTapGesture {
            appearance.impactIfNeed()
            self.daySelected(day)
        }
    }
    
    private func eventStackView() -> some View {
        
        let totalHeight = self.expectSize.height - Metric.eventTopMargin
        let drawableRowCount = Int(totalHeight / Metric.eventRowHeightWithSpacing)
        let maxDrawableEventRowCount = drawableRowCount - 1
        guard maxDrawableEventRowCount > 0 else { return EmptyView().asAnyView() }
        
        let size = min(maxDrawableEventRowCount, self.eventStackModel.linesStack.count)
        let moreEvents = eventStackModel.eventMores(with: size)
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<size, id: \.self) {
                return eventRowView(self.eventStackModel.linesStack[$0])
            }
            eventMoreViews(moreEvents)
        }
        .padding(.top, Metric.eventTopMargin)
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
        let offsetX = CGFloat(line.daysSequence.lowerBound-1) * dayWidth + Metric.eventInterspacing
        let width = CGFloat(line.daysSequence.count) * dayWidth - Metric.eventInterspacing
        let lineColor = self.appearance.colorOnCalendar(line.eventTagId).asColor
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
            return self.state.selectedDay == line.eventStartDayIdentifierOnWeek
            ? self.appearance.colorSet.eventTextSelected.asColor
            : self.appearance.colorSet.eventText.asColor
        }()
        return HStack(spacing: 2) {
             RoundedRectangle(cornerRadius: 12)
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
            return self.state.selectedDay == eventIdOnThisWeek
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
            .padding(.top, 2)
        }
    }
}

// MARK: - preview

final class DummyMonthViewModel: MonthViewModel, @unchecked Sendable {
    
    private let selectedDay = CurrentValueSubject<String?, Never>(nil)
    func attachListener(_ listener: any MonthSceneListener) {
        
    }
    func select(_ day: DayCellViewModel) {
        self.selectedDay.send(day.identifier)
    }
    
    func selectDay(_ day: CalendarDay) {
        self.selectedDay.send("\(day.year)-\(day.month)-\(day.day)")
    }
    
    func clearDaySelection() {
        self.selectedDay.send(nil)
    }

    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        return Just([
            .init(symbol: "SUN", "SUN", isSunday: true),
            .init(symbol: "MON", "MON"),
            .init(symbol: "TUE", "TUE"),
            .init(symbol: "WED", "WED"),
            .init(symbol: "THU", "THU"),
            .init(symbol: "FRI", "FRI"),
            .init(symbol: "SAT", "SAT", isSaturday: true)
        ])
        .eraseToAnyPublisher()
    }

    var weekModels: AnyPublisher<[WeekRowModel], Never> {
        let days: [DayCellViewModel] = (0..<31).map { int -> DayCellViewModel in
            return  DayCellViewModel(year: 2023, month: 09, day: int+1, isNotCurrentMonth: false, accentDay: nil)
        }
        let models = days.enumerated().reduce(into: [WeekRowModel]()) { acc, pair in
            let isSunday = pair.offset % 7 == 0
            let weekIndex = pair.offset / 7
            if isSunday {
                let newWeek = WeekRowModel("id:\(weekIndex)", [pair.element])
                acc.append(newWeek)
            } else {
                let newWeek = WeekRowModel(acc.last!.id, acc.last!.days + [pair.element])
                acc[acc.count-1] = newWeek
            }
        }
        return Just(models).eraseToAnyPublisher()
    }
    
    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        if weekId == "id:0" {
            let event1_5 = EventOnWeek(0..<1, [1, 2, 3, 4, 5], (1...5), ["2023-9-1", "2023-9-2", "2023-9-3", "2023-9-4", "2023-9-5"], DummyCalendarEvent("t1_5", "ev:1_5"))
            let event2_6 = EventOnWeek(0..<1, [2, 3, 4, 5, 6], (2...6), [], DummyCalendarEvent("t2_6", "ev:2_6"))
            
            let event2_3 = EventOnWeek(0..<1, [2, 3], (2...3), ["2023-9-2", "2023-9-3"], DummyCalendarEvent("t2_3", "ev:2_3"))
            let event4_6 = EventOnWeek(0..<1, [4, 5, 6], (4...6), ["2023-9-4", "2023-9-5", "2023-9-6"], DummyCalendarEvent("t4-6", "ev:4_6"))
            
            let event2_3_1 = EventOnWeek(0..<1, [2], (2...2), ["2023-9-2"], DummyCalendarEvent("t2_3_1", "ev:2_3_1", hasPeriod: false))
            let event2_3_2 = EventOnWeek(0..<1, [2, 3], (2...3), ["2023-9-2", "2023-9-3"], DummyCalendarEvent("t2_3_2", "ev:2_3_2", hasPeriod: false))
            let event2_3_3 = EventOnWeek(0..<1, [2, 3], (2...3), ["2023-9-2", "2023-9-3"], DummyCalendarEvent("t2_3_3", "ev:2_3_3", hasPeriod: false))
            
            let lines: [[EventOnWeek]] = [
                [event1_5],
                [event2_6],
                [event2_3, event4_6],
                [event2_3_1],
                [event2_3_2],
                [event2_3_3]
            ]
            return Just(.init(linesStack: lines, shouldMarkEventDays: true))
            .eraseToAnyPublisher()
            
        } else if weekId == "id:1" {
            let eventw2 = EventOnWeek(0..<1, [9, 10, 11, 12], (2...5), [
                "2023-9-9", "2023-9-10", "2023-9-11", "2023-9-12"
            ], DummyCalendarEvent("ev-w2", "ev-w2- hohohohohohohohohohohohoh", hasPeriod: false))
            let lines: [[EventOnWeek]] = [
                [eventw2]
            ]
            return Just(.init(linesStack: lines, shouldMarkEventDays: true))
                .eraseToAnyPublisher()
        } else {
            return Just(.init(linesStack: [], shouldMarkEventDays: false)).eraseToAnyPublisher()
        }
    }

    var currentSelectDayIdentifier: AnyPublisher<String, Never> {
        return self.selectedDay.compactMap{ $0 }.eraseToAnyPublisher()
    }

    var todayIdentifier: AnyPublisher<String, Never> {
        Just("2023-9-4")
            .eraseToAnyPublisher()
    }

    func updateMonthIfNeed(_ newMonth: Domain.CalendarMonth) { }
}


struct MonthViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let viewModel = DummyMonthViewModel()
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        viewAppearance.eventOnCalenarTextAdditionalSize = 7
        viewAppearance.eventOnCalendarIsBold = true
        let eventHandler = MonthViewEventHandler()
        eventHandler.daySelected = viewModel.select(_:)
        let containerView = MonthContainerView(viewAppearance: viewAppearance, eventHandler: eventHandler)
            .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        return containerView
    }
}

private struct DummyCalendarEvent: CalendarEvent {
    var eventId: String
    var name: String
    var eventTime: EventTime?
    var eventTimeOnCalendar: EventTimeOnCalendar?
    var eventTagId: EventTagId
    var isRepeating: Bool = false
    var isForemost: Bool = false

    init(_ id: String, _ name: String, hasPeriod: Bool = true) {
        self.eventId = id
        self.name = name
        self.eventTagId = .default
        if hasPeriod {
            self.eventTimeOnCalendar = .init(.period(0..<1), timeZone: TimeZone.autoupdatingCurrent)
        }
    }
}
