//
//  MonthViewModel.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/05.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes
import Extensions
import CalendarPresentation


// MARK: - MonthViewModel

protocol MonthViewModel: AnyObject, Sendable, MonthSceneInteractor {
    
    func attachListener(_ listener: any MonthSceneListener)
    func select(_ day: DayCellViewModel)
    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel)

    var weekDays: AnyPublisher<[WeekDayModel], Never> { get }
    var weekModels: AnyPublisher<[WeekRowModel], Never> { get }
    var currentSelectDayIdentifier: AnyPublisher<String, Never> { get }
    var todayIdentifier: AnyPublisher<String, Never> { get }
    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never>
    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never>
}

// MARK: - MonthViewModelImple

final class MonthViewModelImple: MonthViewModel, @unchecked Sendable {
    
    private let calendarUsecase: any CalendarUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let eventListUsecase: any CalendarEventListhUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let uiSettingUsecase: any UISettingUsecase
    private weak var listener: (any MonthSceneListener)?
    
    init(
        initialMonth: CalendarMonth,
        calendarUsecase: any CalendarUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        eventListUsecase: any CalendarEventListhUsecase,
        eventTagUsecase: any EventTagUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.calendarUsecase = calendarUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.eventListUsecase = eventListUsecase
        self.eventTagUsecase = eventTagUsecase
        self.uiSettingUsecase = uiSettingUsecase
        
        self.internalBind()
        self.updateMonthIfNeed(initialMonth)
    }
    
    private struct CurrentMonthInfo: Equatable {
        let timeZone: TimeZone
        let component: CalendarComponent
        let range: Range<TimeInterval>

        func shareRange(
            _ kind: CalendarShareRangeKind, for day: DayCellViewModel
        ) -> Range<TimeInterval>? {
            switch kind {
            case .day:
                return CalendarComponent.Day(
                    year: day.year, month: day.month, day: day.day, weekDay: 1
                ).dayRange(self.timeZone)

            case .week:
                return self.component.weeks
                    .first(where: { week in week.days.contains(where: { $0.identifier == day.identifier }) })?
                    .range(self.timeZone)

            case .month:
                return self.component.monthRange(self.timeZone)
            }
        }
    }
    
    private struct Subject: @unchecked Sendable {
        let currentMonthComponent = CurrentValueSubject<CalendarComponent?, Never>(nil)
        let currentMonthInfo = CurrentValueSubject<CurrentMonthInfo?, Never>(nil)
        let userSelectedDay = CurrentValueSubject<CalendarDay?, Never>(nil)
        let eventStackMap = CurrentValueSubject<[String: WeekEventStack], Never>([:])
    }
    private let subject = Subject()
    private let cancellables = CancelBag()
    private var currentMonthComponentsBinding: AnyCancellable?
    private let eventStackBuildingQueue = DispatchQueue(label: "event-stack-builder")
    
    private func internalBind() {
        
        self.bindCurrentMonthInfo()
        self.bindEventsInCurrentMonth()
        self.bindCurerntSelectedDayNotifying()
    }
    
    private func bindCurrentMonthInfo() {
        Publishers.CombineLatest(
            self.calendarSettingUsecase.currentTimeZone,
            self.subject.currentMonthComponent.compactMap { $0 }
        )
        .sink(receiveValue: { [weak self] timeZone, component in
            guard let range = component.intervalRange(at: timeZone) else { return }
            let totalComponent = CurrentMonthInfo(timeZone: timeZone, component: component, range: range)
            self?.subject.currentMonthInfo.send(totalComponent)
        })
        .store(in: self.cancellables)
    }
    
    private func bindEventsInCurrentMonth() {
        
        typealias CurrentMonthAndEvent = (CurrentMonthInfo, [any CalendarEvent])
        let withEventsInThisMonth: (CurrentMonthInfo) -> AnyPublisher<CurrentMonthAndEvent, Never>
        withEventsInThisMonth = { [weak self] month in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            return self.calendarEvents(from: month)
                .map { (month, $0) }
                .eraseToAnyPublisher()
        }
        
        let arrangeEventStacks: (CurrentMonthAndEvent) -> [String: WeekEventStack]
        arrangeEventStacks = { pair in
            let (current, events) = pair
            let weeks = current.component.weeks
            let stackBuilder = WeekEventStackBuilder(current.timeZone)
            return weeks.reduce(into: [String: WeekEventStack]()) { acc, week in
                let stack = stackBuilder.build(week, events: events)
                acc[week.id] = stack
            }
        }
        self.subject.currentMonthInfo.compactMap { $0 }
            .map(withEventsInThisMonth)
            .switchToLatest()
            .map(arrangeEventStacks)
            .subscribe(on: self.eventStackBuildingQueue)
            .sink(receiveValue: { [weak self] stackMap in
                self?.subject.eventStackMap.send(stackMap)
            })
            .store(in: self.cancellables)
    }
    
    private func bindCurerntSelectedDayNotifying() {
     
        typealias DayAndEventIds = (CurrentSelectDayModel, [any CalendarEvent])
        let withEvents: (CurrentSelectDayModel) -> AnyPublisher<DayAndEventIds, Never>
        withEvents = { [weak self] model in
            guard let self = self else { return Empty().eraseToAnyPublisher() }
            let eventIds = self.eventStack(at: model.weekId)
                .map { $0.events(in: model.day) }
            return eventIds.map { (model, $0) }
                .eraseToAnyPublisher()
        }
        
        self.currentSelectedDay
            .map(withEvents)
            .switchToLatest()
            .sink(receiveValue: { [weak self] pair in
                self?.listener?.monthScene(didChange: pair.0, and: pair.1)
            })
            .store(in: self.cancellables)
    }
}


extension MonthViewModelImple {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth) {
        
        let current = self.subject.currentMonthComponent.value
        let shouldChange = current?.year != newMonth.year || current?.month != newMonth.month
        guard shouldChange else { return }
        
        self.currentMonthComponentsBinding?.cancel()
        
        self.subject.userSelectedDay.send(nil)
        self.currentMonthComponentsBinding = self.calendarUsecase
            .components(for: newMonth.month, of: newMonth.year)
            .sink(receiveValue: { [weak self] component in
                self?.subject.currentMonthComponent.send(component)
            })
    }
    
    func attachListener(_ listener: any MonthSceneListener) {
        self.listener = listener
    }
    
    func select(_ day: DayCellViewModel) {
        self.subject.userSelectedDay.send(
            .init(day.year, day.month, day.day)
        )
    }

    func shareEvents(_ kind: CalendarShareRangeKind, for day: DayCellViewModel) {
        guard let info = self.subject.currentMonthInfo.value,
              let range = info.shareRange(kind, for: day)
        else { return }
        self.listener?.monthScene(didRequestShare: range, kind: kind)
    }

    func clearDaySelection() {
        self.subject.userSelectedDay.send(nil)
    }
    
    func selectDay(_ day: CalendarDay) {
        self.subject.userSelectedDay.send(day)
    }
}

extension MonthViewModelImple {
    
    private func calendarEvents(from info: CurrentMonthInfo) -> AnyPublisher<[any CalendarEvent], Never> {
        
        let activeHolidays = self.eventTagUsecase.offEventTagIdsOnCalendar().map { offIds -> [any CalendarEvent] in
            guard !offIds.contains(.holiday) else { return [] }
            let holidayCalenarEvents = info.component.holidayCalendarEvents(with: info.timeZone)
            return holidayCalenarEvents
        }
        
        let transform: ([any CalendarEvent], [any CalendarEvent]) -> [any CalendarEvent]
        transform = { events, holidays in
            return events + holidays
        }
        return Publishers.CombineLatest(
            self.eventListUsecase.calendarEvents(in: info.range),
            activeHolidays
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
    
    var weekDays: AnyPublisher<[WeekDayModel], Never> {
        let transform: (DayOfWeeks) -> [WeekDayModel] = { dayOfWeek in
            return WeekDayModel.allModels(of: dayOfWeek)
        }
        return self.calendarSettingUsecase.firstWeekDay
            .map(transform)
            .eraseToAnyPublisher()
    }
    
    var weekModels: AnyPublisher<[WeekRowModel], Never> {

        let transform: (CurrentMonthInfo) -> [WeekRowModel]
        transform = { current in
            return current.component.weeks.map { week -> WeekRowModel in
                return .init(week, month: current.component.month)
            }
        }
        
        return self.subject.currentMonthInfo.compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    private var currentSelectedDay: AnyPublisher<CurrentSelectDayModel, Never> {
        let transform: (CalendarDay?, CalendarComponent.Day, CurrentMonthInfo) -> CurrentSelectDayModel?
        transform = { selected, today, thisMonth -> CurrentSelectDayModel? in
            switch (selected, today, thisMonth) {
            case (.some(let day), _, let month):
                return .init(day: day, month.component, month.timeZone)
            case (_, let t, let m)
                where t.year == m.component.year && t.month == m.component.month:
                return .init(today: t, m.component, m.timeZone)
            case (_, _, let m):
                return .init(firstDayOf: m.component, m.timeZone)
            }
        }
        return Publishers.CombineLatest3(
            self.subject.userSelectedDay,
            self.calendarUsecase.currentDay.removeDuplicates(),
            self.subject.currentMonthInfo.compactMap { $0 }
        )
        .compactMap(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var currentSelectDayIdentifier: AnyPublisher<String, Never> {
        return self.currentSelectedDay
            .map { $0.identifier }
            .eraseToAnyPublisher()
    }
    
    var todayIdentifier: AnyPublisher<String, Never> {
        return self.calendarUsecase.currentDay
            .map { "\($0.year)-\($0.month)-\($0.day)" }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    func eventStack(at weekId: String) -> AnyPublisher<WeekEventStackViewModel, Never> {
        let transform: (CalendarAppearanceSettings, [[EventOnWeek]]) -> WeekEventStackViewModel
        transform = { uiSetting, lines in
            return .init(linesStack: lines, shouldMarkEventDays: uiSetting.showUnderLineOnEventDay)
        }
        return Publishers.CombineLatest(
            self.uiSettingUsecase.currentCalendarUISeting,
            self.eventStackElements(at: weekId)
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    func eventsPerDay(at weekId: String) -> AnyPublisher<[[any CalendarEvent]], Never> {
        return self.subject.eventStackMap
            .compactMap { $0[weekId] }
            .map { $0.eventsPerDay }
            .eraseToAnyPublisher()
    }
    
    private func eventStackElements(at weekId: String) -> AnyPublisher<[[EventOnWeek]], Never> {
        return self.subject.eventStackMap
            .compactMap { $0[weekId] }
            .map{ $0.eventStacks }
            .eraseToAnyPublisher()
    }
}


// MARK: - private extensions

private extension CalendarComponent {
    
    func intervalRange(at timeZone: TimeZone) -> Range<TimeInterval>? {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let startDay = self.weeks.first?.days.first,
              let endDay = self.weeks.last?.days.last,
              let startDate = calendar.date(from: startDay).flatMap(calendar.startOfDay(for:)),
              let endDate = calendar.date(from: endDay).flatMap(calendar.endOfDay(for:))
        else { return nil }
        
        return startDate.timeIntervalSince1970..<endDate.timeIntervalSince1970
    }
    
    func holidayCalendarEvents(with timeZone: TimeZone) -> [any CalendarEvent] {
        return self.weeks
            .flatMap { $0.days }
            .flatMap { $0.holidays }
            .compactMap { HolidayCalendarEvent($0, in: timeZone) }
    }
}

private extension WeekEventStackViewModel {
    
    func events(in day: Int) -> [any CalendarEvent] {
        return self.linesStack.reduce(into: [any CalendarEvent]()) { acc, lines in
            guard let eventLineOnDay = lines.first (where: { $0.overlapDays.contains(day) })
            else { return }
            acc += [eventLineOnDay.event]
        }
    }
}

private extension CurrentSelectDayModel {
    
    init?(
        day: CalendarDay,
        _ component: CalendarComponent,
        _ timeZone: TimeZone
    ) {
        self.init(
            day.year, day.month, day.day, component, timeZone
        )
        self.holidays = component.holiday(day.month, day.day) ?? []
    }
    
    init?(
        today: CalendarComponent.Day,
        _ component: CalendarComponent,
        _ timeZone: TimeZone
    ) {
        self.init(today.year, today.month, today.day, component, timeZone)
        self.holidays = component.holiday(today.month, today.day) ?? []
    }
    
    init?(
        firstDayOf month: CalendarComponent,
        _ timeZone: TimeZone
    ) {
        guard let firstDay = month.weeks.flatMap({ $0.days }).first(where: { $0.month == month.month && $0.day == 1 })
        else { return nil }
        self.init(firstDay.year, firstDay.month, firstDay.day, month, timeZone)
        self.holidays = month.holiday(firstDay.month, firstDay.day) ?? []
    }
    
    private init?(
        _ year: Int, _ month: Int, _ day: Int,
        _ component: CalendarComponent, _ timeZone: TimeZone
    ) {
        let identifier = "\(year)-\(month)-\(day)"
        let findWeekContainsDay: (CalendarComponent.Week) -> Bool = { week in
            return week.days.first(where: { $0.identifier == identifier }) != nil
        }
        guard let week = component.weeks.first(where: findWeekContainsDay)
        else { return nil }
        
        let component = DateComponents(year: year, month: month, day: day)
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        guard let date = calendar.date(from: component),
              let range = calendar.dayRange(date)
        else { return nil }
        self.init(year, month, day, weekId: week.id, range: range)
    }
}
