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
import Extensions
import Scenes
import CommonPresentation
import CalendarPresentation

@Observable final class MonthViewState {
    
    fileprivate var weekDays: [WeekDayModel] = []
    fileprivate var weeks: [WeekRowModel] = []
    fileprivate var selectedDay: String?
    fileprivate var today: String?
    fileprivate var isCollapsed: Bool = false
    @ObservationIgnored var eventStacks: (String) -> AnyPublisher<WeekEventStackViewModel, Never> = { _ in
        Empty().eraseToAnyPublisher()
    }
    @ObservationIgnored var eventsPerDay: (String) -> AnyPublisher<[[any CalendarEvent]], Never> = { _ in
        Empty().eraseToAnyPublisher()
    }
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()
    
    func bind(_ viewModel: any MonthViewModel, _ appearance: ViewAppearance) {
        guard self.didBind == false else { return }
        self.didBind = true
        
        self.eventStacks = viewModel.eventStack(at:)
        self.eventsPerDay = viewModel.eventsPerDay(at:)
        
        viewModel.weekDays
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] days in
                self?.weekDays = days
            })
            .store(in: self.cancellables)
        
        viewModel.weekModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] models in
                self?.weeks = models
            })
            .store(in: self.cancellables)
        
        viewModel.currentSelectDayIdentifier
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] identifier in
                self?.selectedDay = identifier
            })
            .store(in: self.cancellables)
        
        viewModel.todayIdentifier
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] identifier in
                self?.today = identifier
            })
            .store(in: self.cancellables)

        // 첫 값은 이 페이지의 초기 상태 반영이라 애니메이션을 태우지 않는다 —
        // 아직 안 그려진 달 페이지가 뒤늦게 구독하면 펼쳐진 채 그려졌다 접히는 게 보인다
        var isInitialCollapsedValue = true
        // 당겨서 펼치기는 스크롤 도중에 발화한다 — RunLoop.main 은 default 모드에서만
        // 전달해 트래킹·감속이 끝나야 반영된다
        viewModel.isMonthCollapsed
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self, weak appearance] isCollapsed in
                let animation: Animation? = isInitialCollapsedValue ? nil : .easeInOut(duration: 0.3)
                isInitialCollapsedValue = false
                appearance?.withAnimationIfNeed(animation) {
                    self?.isCollapsed = isCollapsed
                }
            })
            .store(in: self.cancellables)
    }
}

final class MonthViewEventHandler: Observable {
    var daySelected: (DayCellViewModel) -> Void = { _ in }
    var shareEvents: (CalendarShareRangeKind, DayCellViewModel) -> Void = { _, _ in }
    var toggleMonthCollapse: () -> Void = { }

    func bind(_ viewModel: any MonthViewModel) {
        self.daySelected = viewModel.select(_:)
        self.shareEvents = viewModel.shareEvents(_:for:)
        self.toggleMonthCollapse = viewModel.toggleMonthCollapse
    }
}

struct MonthContainerView: View {
    
    @State private var state: MonthViewState = .init()
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
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}


struct MonthView: View {
    
    @Environment(MonthViewState.self) private var state
    @Environment(MonthViewEventHandler.self) private var eventHandler
    @Environment(ViewAppearance.self) private var appearance
    @State private var gridHeight: CGFloat?
    
    var body: some View {
        VStack(spacing: 0) {
            WeekDaysHeaderView(weekDays: self.state.weekDays)
            if state.weeks.isEmpty {
                self.emptyGridView()
            } else {
                self.gridWeeksView()
            }
            if state.isCollapsed {
                self.expandMonthButton()
            }
        }
        .padding([.leading, .trailing], 8)
        .background(self.appearance.colorSet.dayBackground.asColor)
    }

    private func expandMonthButton() -> some View {
        Button {
            self.appearance.impactIfNeed()
            self.eventHandler.toggleMonthCollapse()
        } label: {
            Image(systemName: "chevron.down")
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, spacing: .xsmall)
                .contentShape(Rectangle())
        }
    }
    
    private func gridWeeksView() -> some View {
        let isCollapsed = self.state.isCollapsed
        let rowHeight = isCollapsed ? RowHeightOnCalendar.small.cgValue : appearance.rowHeightOnCalendar.cgValue
        let weeks = isCollapsed ? self.collapsedWeeks : self.state.weeks
        return GeometryReader { proxy in
            let expectSize = CGSize(width: proxy.size.width, height: rowHeight)
            VStack(spacing: 0) {
                ForEach(weeks, id: \.id) {
                    WeekRowView(
                        week: $0, expectSize, isCollapsed: isCollapsed,
                        selectedDay: state.selectedDay,
                        today: state.today,
                        focusedMonth: nil,
                        eventsPerDay: state.eventsPerDay($0.id),
                        eventStack: state.eventStacks($0.id)
                    )
                    .eventHandler(\.daySelected, eventHandler.daySelected)
                    .eventHandler(\.shareEvents, eventHandler.shareEvents)
                    .environment(appearance)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { self.gridHeight = $0 }
        }
        // 행은 날짜 글자 높이만큼 rowHeight 보다 커서, 첫 프레임 뒤엔 실제 그린 높이를 쓴다
        .frame(height: self.gridHeight ?? rowHeight * CGFloat(weeks.count))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.CalendarScene.monthGrid)
    }
    
    private var collapsedWeeks: [WeekRowModel] {
        let weekOfSelectedDay = self.state.weeks.first { week in
            week.days.contains { $0.identifier == self.state.selectedDay }
        }
        guard let week = weekOfSelectedDay ?? self.state.weeks.first else { return [] }
        return [week]
    }

    private func emptyGridView() -> some View {
        Rectangle()
            .fill(appearance.colorSet.dayBackground.asColor)
            .frame(height: 500)
    }
}

// MARK: - preview

final class DummyMonthViewModel: MonthViewModel, @unchecked Sendable {
    
    private let selectedDay = CurrentValueSubject<String?, Never>(nil)
    private let collapsed = CurrentValueSubject<Bool, Never>(false)
    func attachListener(_ listener: any MonthSceneListener) {
        
    }
    func select(_ day: DayCellViewModel) {
        self.selectedDay.send(day.identifier)
    }

    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel) {
    }

    func selectDay(_ day: CalendarDay) {
        self.selectedDay.send("\(day.year)-\(day.month)-\(day.day)")
    }
    
    func clearDaySelection() {
        self.selectedDay.send(nil)
    }

    func updateMonthCollapsed(_ isCollapsed: Bool) {
        self.collapsed.send(isCollapsed)
    }

    func toggleMonthCollapse() {
        self.collapsed.send(!self.collapsed.value)
    }

    var isMonthCollapsed: AnyPublisher<Bool, Never> {
        return self.collapsed.eraseToAnyPublisher()
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
    
    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never> {
        let evs = (0..<1).map { DummyCalendarEvent("id:\($0)", "name:\($0)") }
        return Just(
            [evs, evs, evs, evs, evs, evs, evs]
        )
        .eraseToAnyPublisher()
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
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        viewAppearance.eventOnCalenarTextAdditionalSize = 7
        viewAppearance.eventOnCalendarIsBold = true
        viewAppearance.updateEventColorMap(by: [
            DefaultEventTag.default("#ff00ff"),
            DefaultEventTag.holiday("#ff0000")
        ])
        viewAppearance.rowHeightOnCalendar = .small
        let eventHandler = MonthViewEventHandler()
        eventHandler.daySelected = viewModel.select(_:)
        let containerView = MonthContainerView(viewAppearance: viewAppearance, eventHandler: eventHandler)
            .eventHandler(\.stateBinding, { $0.bind(viewModel, viewAppearance) })
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
    var locationText: String?

    init(_ id: String, _ name: String, hasPeriod: Bool = true) {
        self.eventId = id
        self.name = name
        self.eventTagId = .default
        if hasPeriod {
            self.eventTimeOnCalendar = .init(.period(0..<1), timeZone: TimeZone.autoupdatingCurrent)
        }
    }
}
