//
//  WidgetCalendarEventFetchUsecase.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - CalendarEventFetchUsecase + CalendarEvents

struct CalendarEvents {
    var currentTodos: [TodoCalendarEvent]
    var eventWithTimes: [any CalendarEvent]
    var customTagMap: [String: CustomEventTag]
    var googleCalendarColors: GoogleCalendar.Colors?
    var googleCalendarTags: [String: GoogleCalendar.Tag] = [:]
    var appleCalendarTags: [String: AppleCalendar.Tag] = [:]

    init() {
        self.currentTodos = []
        self.eventWithTimes = []
        self.customTagMap = [:]
    }
    
    func findFirstFutureEvent(from time: TimeInterval, todayRange: Range<TimeInterval>) -> (any CalendarEvent)? {
        return self.eventWithTimes.first(where: {
            self.isTodayNextEvent($0, time, todayRange)
        })
    }
    
    func findNextEvents(
        from time: TimeInterval, todayRange: Range<TimeInterval>
    ) -> [any CalendarEvent] {
        return self.eventWithTimes.filter {
            self.isTodayNextEvent($0, time, todayRange)
        }
    }
    
    private func isTodayNextEvent(
        _ event: any CalendarEvent, _ current: TimeInterval, _ todayRange: Range<TimeInterval>
    ) -> Bool {
        guard !(event is HolidayCalendarEvent),
                let eventTime = event.eventTime,
              todayRange ~= eventTime.lowerBoundWithFixed
        else { return false }
        return eventTime.lowerBoundWithFixed > current
    }
}

struct ForemostEvent {
    let foremostEvent: (any ForemostMarkableEvent)?
    let tag: CustomEventTag?
}

struct TodayNextEvent {
    let nextEvent: any CalendarEvent
    let tag: CustomEventTag?
    var andThenNextEventStartDate: Date?
}

struct TodayNextEvents {
    let nextEvents: [any CalendarEvent]
    let customTags: [CustomEventTag]
}

// MARK: - D-day 대상

enum DDayTargetKind: String, Sendable {
    case schedule
    case holiday
}

struct DDayTargetEventId: Sendable, Hashable {

    let kind: DDayTargetKind
    let rawId: String
    /// 반복 일정의 지정 회차. `EventTime.customKey`. 단일 일정·공휴일은 nil.
    let turnKey: String?

    init(kind: DDayTargetKind, rawId: String, turnKey: String? = nil) {
        self.kind = kind
        self.rawId = rawId
        self.turnKey = turnKey
    }
}

struct DDayTargetEvent: Sendable {

    let targetId: DDayTargetEventId
    let name: String
    let time: EventTime
    /// 반복 일정일 때만 값이 있다 — 위젯이 "매주 월" 같은 요약을 표시하는 데 쓴다.
    let repeatOption: (any EventRepeatingOption)?
    /// 반복옵션 요약 텍스트 산출에 필요한 기준 시각 (원본 반복 시작 시각).
    let repeatStartTime: Date?

    var isRepeating: Bool {
        return self.repeatOption != nil
    }
}

/// 공휴일 D-day 대상 키. `uuid`는 연도별 remote id라 재조회에 쓸 수 없어
/// 국가·날짜·이름 조합으로 지목한다.
struct HolidayTargetKey {

    let countryCode: String
    let dateString: String
    let name: String

    init(countryCode: String, dateString: String, name: String) {
        self.countryCode = countryCode
        self.dateString = dateString
        self.name = name
    }

    /// name에 `::`가 들어갈 수 있으므로 앞 두 세그먼트만 분리하고 나머지를 name으로 본다.
    init?(rawId: String) {
        let segments = rawId.components(separatedBy: "::")
        guard segments.count >= 3 else { return nil }
        self.countryCode = segments[0]
        self.dateString = segments[1]
        self.name = segments.dropFirst(2).joined(separator: "::")
    }

    var rawId: String {
        return "\(self.countryCode)::\(self.dateString)::\(self.name)"
    }

    var year: Int? {
        return self.dateString.components(separatedBy: "-").first.flatMap { Int($0) }
    }

    /// `holidaysGivenYears`는 range의 시작·끝 연도를 계산해 그 연도들을 로드한다.
    /// 대상 연도 하나만 로드하도록 그 해 중간(6월 1일)의 1초 range를 만든다.
    var yearRange: Range<TimeInterval>? {
        guard let year,
              let date = Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: year, month: 6, day: 1))
        else { return nil }
        let start = date.timeIntervalSince1970
        return start..<(start + 1)
    }
}


protocol CalendarEventFetchUsecase {

    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone,
        withoutOffTagIds: Bool
    ) async throws -> CalendarEvents
    
    func fetchForemostEvent() async throws -> ForemostEvent
    
    func fetchNextEvent(
        _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvent?
    
    func fetchNextEvents(
        _ refTime: Date, withIn todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvents

    /// D-day 위젯 대상 단건 조회. 반복 일정은 `target.turnKey`가 지목한 회차 시각으로 해석한다.
    /// 대상이 삭제됐거나 그 회차가 제외·종료 범위 밖이면 nil.
    func fetchDDayTargetEvent(
        _ target: DDayTargetEventId
    ) async throws -> DDayTargetEvent?

    /// 반복 일정의 회차 목록. 위젯 편집의 회차 선택 후보로 쓴다.
    func fetchScheduleRepeatingTurns(
        _ scheduleId: String, in range: Range<TimeInterval>, limit: Int
    ) async throws -> [RepeatingTimes]
}

extension CalendarEventFetchUsecase {
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> CalendarEvents {
        return try await self.fetchEvents(in: range, timeZone, withoutOffTagIds: false)
    }
}


// MARK: - CalendarEventFetchUsecaseImple

actor CalendarEventsFetchCacheStore {
    
    struct Storage {
        var currentTodos: [TodoCalendarEvent]?
        var allCustomTagsMap: [String: CustomEventTag]?
        var externalAccountMap: [String: ExternalServiceAccountinfo]?
        var googleCalendarColors: GoogleCalendar.Colors?
        var googleCalendarTags: [String: GoogleCalendar.Tag]?
        var appleCalendarTags: [String: AppleCalendar.Tag]?
        var eventDetails: [String: EventDetailData] = [:]
    }
    
    private var storage = Storage()
    
    func update<T>(_ keyPath: WritableKeyPath<CalendarEventsFetchCacheStore.Storage, T>, _ newValue: T) {
        self.storage[keyPath: keyPath] = newValue
    }
    
    func update<T>(
        _ keyPath: WritableKeyPath<CalendarEventsFetchCacheStore.Storage, T>,
        mutate: (T) -> T
    ) {
        let oldValue = self.storage[keyPath: keyPath]
        let newValue = mutate(oldValue)
        self.storage[keyPath: keyPath] = newValue
    }
    
    func value<T>(
        _ keyPath: KeyPath<CalendarEventsFetchCacheStore.Storage, T>
    ) -> T {
        return self.storage[keyPath: keyPath]
    }

    func reset() {
        self.storage = .init()
    }
    
    func resetCurrentTodo() {
        self.storage.currentTodos = nil
    }
}


final class CalendarEventFetchUsecaseImple: CalendarEventFetchUsecase, @unchecked Sendable {
    
    private let todoRepository: any TodoEventRepository
    private let scheduleRepository: any ScheduleEventRepository
    private let foremostEventRepository: any ForemostEventRepository
    private let holidayFetchUsecase: any HolidaysFetchUsecase
    private let eventTagRepository: any EventTagRepository
    private let externalCalendarIntegrateRepository: any ExternalCalendarIntegrateRepository
    private let googleCalendarRepository: any GoogleCalendarRepository
    private let appleCalendarRepository: any AppleCalendarRepository
    private let eventDetailRepository: any EventDetailDataRepository
    private let cached: CalendarEventsFetchCacheStore

    init(
        todoRepository: any TodoEventRepository,
        scheduleRepository: any ScheduleEventRepository,
        foremostEventRepository: any ForemostEventRepository,
        holidayFetchUsecase: any HolidaysFetchUsecase,
        eventTagRepository: any EventTagRepository,
        externalCalendarIntegrateRepository: any ExternalCalendarIntegrateRepository,
        googleCalendarRepository: any GoogleCalendarRepository,
        appleCalendarRepository: any AppleCalendarRepository,
        eventDetailRepository: any EventDetailDataRepository,
        cached: CalendarEventsFetchCacheStore
    ) {
        self.todoRepository = todoRepository
        self.scheduleRepository = scheduleRepository
        self.foremostEventRepository = foremostEventRepository
        self.holidayFetchUsecase = holidayFetchUsecase
        self.eventTagRepository = eventTagRepository
        self.externalCalendarIntegrateRepository = externalCalendarIntegrateRepository
        self.googleCalendarRepository = googleCalendarRepository
        self.appleCalendarRepository = appleCalendarRepository
        self.eventDetailRepository = eventDetailRepository
        self.cached = cached
    }
}

extension CalendarEventFetchUsecaseImple {
    
    func fetchEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone,
        withoutOffTagIds: Bool
    ) async throws -> CalendarEvents {
        
        let customTagMap = try await self.allCustomEventTagMap()
        let currentTodos = try await self.currentTodoEvents(timeZone)
        let todosInRange = try await self.todoEvents(in: range, timeZone)
        let schedulesInRange = try await self.scheduleEvents(in: range, timeZone)
        let holidaysInRage = try await self.holidays(in: range, timeZone)
        
        var eventsWithTime: [any CalendarEvent] = todosInRange + schedulesInRange + holidaysInRage
        
        var events = CalendarEvents()
        events.currentTodos = currentTodos
        events.customTagMap = customTagMap
        
        if await self.checkGoogleCalendarIntegrated() {
            events.googleCalendarColors = try? await self.googleCalendarColors()
            if let tags = try? await self.googleCalendarTags() {
                events.googleCalendarTags = tags
                let allTagIds = Array(tags.keys)
                let googleEvents = (try? await self.googleCalendarEvents(allTagIds, in: range, timeZone)) ?? []
                eventsWithTime += googleEvents
            }
        }

        if await self.checkAppleCalendarIntegrated() {
            if let tags = try? await self.appleCalendarTags() {
                events.appleCalendarTags = tags
            }
            let appleEvents = (try? await self.appleCalendarEvents(in: range, timeZone)) ?? []
            eventsWithTime += appleEvents
        }

        events.eventWithTimes = eventsWithTime.sorted()
        
        if withoutOffTagIds {
            let offIds = self.eventTagRepository.loadOffTags()
            events.currentTodos = events.currentTodos.filter {
                !offIds.contains($0.eventTagId)
            }
            events.eventWithTimes = events.eventWithTimes.filter {
                !offIds.contains($0.eventTagId)
            }
        }
        
        return events
    }

    private func allCustomEventTagMap() async throws -> [String: CustomEventTag] {
        if let cached = await self.cached.value(\.allCustomTagsMap) {
            return cached
        }
        let tags = try await self.eventTagRepository.loadAllCustomTags()
            .values.first(where: { _ in true }) ?? []
        let tagMap = tags.asDictionary { $0.uuid }
        await self.cached.update(\.allCustomTagsMap, tagMap)
        return tagMap
    }
    
    private func checkGoogleCalendarIntegrated() async -> Bool {
        let serviceId = GoogleCalendarService.id
        if let cached = await self.cached.value(\.externalAccountMap) {
            return cached[serviceId] != nil
        }
        let accounts = (try? await self.externalCalendarIntegrateRepository.loadIntegratedAccounts()) ?? []
        let accountMap = accounts.asDictionary{ $0.serviceIdentifier }
        await self.cached.update(\.externalAccountMap, accountMap)
        return accountMap[serviceId] != nil
    }
    
    private func googleCalendarColors() async throws -> GoogleCalendar.Colors {
        if let cached = await self.cached.value(\.googleCalendarColors) {
            return cached
        }
        let colors = try await self.googleCalendarRepository.loadColors()
            .values.first(where: { _ in true }) ?? .init(ownerId: "", calendars: [:], events: [:])
        await self.cached.update(\.googleCalendarColors, colors)
        return colors
    }
    
    private func googleCalendarTags() async throws -> [String: GoogleCalendar.Tag] {
        if let cached = await self.cached.value(\.googleCalendarTags) {
            return cached
        }
        let tags = try await self.googleCalendarRepository.loadCalendarTags()
            .values.first(where: { _ in true }) ?? []
        let tagMap = tags.asDictionary { $0.id }
        await self.cached.update(\.googleCalendarTags, tagMap)
        return tagMap
    }
    
    private func currentTodoEvents(
        _ timeZone: TimeZone
    ) async throws -> [TodoCalendarEvent] {
        if let cached = await self.cached.value(\.currentTodos) {
            return cached
        }
        let todos = (try await self.todoRepository.loadCurrentTodoEvents()
            .values.first(where: { _ in true }) ?? [])
            .map { TodoCalendarEvent($0, in: timeZone) }
        await self.cached.update(\.currentTodos, todos)
        return todos
    }
    
    private func todoEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [TodoCalendarEvent] {
        let todos = try await self.todoRepository.loadTodoEvents(in: range)
            .values.first(where: { _ in true }) ?? []
        return todos.map { TodoCalendarEvent($0, in: timeZone) }
    }
    
    private func scheduleEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [ScheduleCalendarEvent] {
        let events = try await scheduleRepository.loadScheduleEvents(in: range)
            .values.first(where: { _ in true }) ?? []
        let eventContainer = MemorizedEventsContainer<ScheduleEvent>()
            .refresh(events, in: range)
        let eventWithRepeatTimeCalculated = eventContainer.allCachedEvents()
        return eventWithRepeatTimeCalculated.flatMap {
            ScheduleCalendarEvent.events(from: $0, in: timeZone)
        }
    }
    
    private func holidays(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [HolidayCalendarEvent] {
        let holidays = try await self.holidayFetchUsecase.holidaysGivenYears(
            range, timeZone: timeZone
        )
        let events = holidays.compactMap { HolidayCalendarEvent($0, in: timeZone) }
        return events.filter { $0.eventTime?.isRoughlyOverlap(with: range) ?? false }
    }
    
    private func googleCalendarEvents(
        _ calendarIds: [String],
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [GoogleCalendarEvent] {
        let events = try await calendarIds.async.reduce(into: [GoogleCalendar.Event]()) { [weak self] acc, id in

            let list = try await self?.googleCalendarRepository.loadEvents(id, in: range)
                .values.first(where: { _ in true }) ?? []
            acc += list
        }
        let calendarEvents = events.map { GoogleCalendarEvent($0, in: timeZone) }
        return calendarEvents
    }

    private func checkAppleCalendarIntegrated() async -> Bool {
        let serviceId = AppleCalendarService.id
        if let cached = await self.cached.value(\.externalAccountMap) {
            return cached[serviceId] != nil
        }
        let accounts = (try? await self.externalCalendarIntegrateRepository.loadIntegratedAccounts()) ?? []
        let accountMap = accounts.asDictionary { $0.serviceIdentifier }
        await self.cached.update(\.externalAccountMap, accountMap)
        return accountMap[serviceId] != nil
    }

    private func appleCalendarTags() async throws -> [String: AppleCalendar.Tag] {
        if let cached = await self.cached.value(\.appleCalendarTags) {
            return cached
        }
        let tags = try await self.appleCalendarRepository.loadCalendarTags()
            .values.first(where: { _ in true }) ?? []
        let tagMap = tags.asDictionary { $0.id }
        await self.cached.update(\.appleCalendarTags, tagMap)
        return tagMap
    }

    private func appleCalendarEvents(
        in range: Range<TimeInterval>,
        _ timeZone: TimeZone
    ) async throws -> [AppleCalendarEvent] {
        let events = try await self.appleCalendarRepository.loadEvents(in: range)
            .values.first(where: { _ in true }) ?? []
        return events.map { AppleCalendarEvent($0, in: timeZone) }
    }
    
    private func selectLocationText(_ event: any CalendarEvent) async throws -> String? {
        
        func locationFromPlace(_ eventId: String) async throws -> Place? {
            if let cached = await self.cached.value(\.eventDetails)[eventId] {
                return cached.place
            }
            let detail = try await self.eventDetailRepository.loadDetail(eventId).values.first(where: { _ in true })
            await self.cached.update(\.eventDetails) { old in
                return old |> key(eventId) .~ detail
            }
            return detail?.place
        }
        
        switch event {
        case let todo as TodoCalendarEvent:
            return try await locationFromPlace(todo.eventId)?.placeName
            
        case let schedule as ScheduleCalendarEvent:
            return try await locationFromPlace(schedule.eventIdWithoutTurn)?.placeName
            
        case let google as GoogleCalendarEvent:
            return google.locationText

        case let apple as AppleCalendarEvent:
            return apple.locationText

        default: return nil
        }
    }
}

extension CalendarEventFetchUsecaseImple {
    
    func fetchForemostEvent() async throws -> ForemostEvent {
        let tags = try await self.allCustomEventTagMap()
        let event = try await self.loadForemostEvent()
        return ForemostEvent(
            foremostEvent: event,
            tag: event.flatMap { $0.eventTagId?.customTagId }.flatMap { tags[$0] }
        )
    }
    
    private func loadForemostEvent() async throws -> (any ForemostMarkableEvent)? {
        return try await self.foremostEventRepository.foremostEvent().values.first(where: { _ in true }) ?? nil
    }
}

extension CalendarEventFetchUsecaseImple {
    
    func fetchNextEvent(
        _ refTime: Date, within todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvent? {
        
        let events = try await self.fetchEvents(in: todayRange, timeZone, withoutOffTagIds: true)
        
        guard var firstFutureEvent = events.findFirstFutureEvent(from: refTime.timeIntervalSince1970, todayRange: todayRange)
        else {
            return nil
        }
        firstFutureEvent.locationText = try? await self.selectLocationText(firstFutureEvent)
        
        let secondFutureEvent = firstFutureEvent.eventTime.flatMap {
            return events.findFirstFutureEvent(from: $0.lowerBoundWithFixed, todayRange: todayRange)
        }
        let tag = firstFutureEvent.eventTagId.customTagId.flatMap {
            return events.customTagMap[$0]
        }
        
        return TodayNextEvent(nextEvent: firstFutureEvent, tag: tag)
            |> \.andThenNextEventStartDate .~ secondFutureEvent?.eventTime.map {
                Date(timeIntervalSince1970: $0.lowerBoundWithFixed)
            }
    }
    
    func fetchNextEvents(
        _ refTime: Date, withIn todayRange: Range<TimeInterval>, _ timeZone: TimeZone
    ) async throws -> TodayNextEvents {
        
        let events = try await self.fetchEvents(in: todayRange, timeZone, withoutOffTagIds: true)
        let todayEvents = events.findNextEvents(
            from: refTime.timeIntervalSince1970, todayRange: todayRange
        )
        
        let customTags = todayEvents
            .compactMap { $0.eventTagId.customTagId }
            .compactMap { events.customTagMap[$0] }
        
        return TodayNextEvents(nextEvents: todayEvents, customTags: customTags)
    }
}

// MARK: - D-day 대상 조회

extension CalendarEventFetchUsecaseImple {

    private enum Constant {
        /// 회차 복원·열거 시 최대 전진 횟수. 종료 없는 반복의 폭주를 막는 상한.
        static let maxTurnAdvance: Int = 3650
    }

    func fetchDDayTargetEvent(
        _ target: DDayTargetEventId
    ) async throws -> DDayTargetEvent? {

        switch target.kind {
        case .schedule: return await self.fetchDDayTargetSchedule(target)
        case .holiday:  return await self.fetchDDayTargetHoliday(target)
        }
    }

    func fetchScheduleRepeatingTurns(
        _ scheduleId: String, in range: Range<TimeInterval>, limit: Int
    ) async throws -> [RepeatingTimes] {

        guard let schedule = await self.loadSchedule(scheduleId),
              let repeating = schedule.repeating,
              let enumerator = self.makeEnumerator(schedule)
        else { return [] }

        let origin = RepeatingTimes(time: schedule.time, turn: 1)
        let isInRange: (EventTime) -> Bool = {
            $0.upperBoundWithFixed >= range.lowerBound
                && $0.lowerBoundWithFixed < range.upperBound
        }

        var turns: [RepeatingTimes] = []
        if isInRange(origin.time),
           !schedule.repeatingTimeToExcludes.contains(origin.time.customKey) {
            turns.append(origin)
        }

        var current = origin
        var advanced = 0
        while turns.count < limit, advanced < Constant.maxTurnAdvance {
            guard let next = enumerator.nextEventTime(
                from: current, until: repeating.repeatingEndOption?.endTime
            )
            else { break }
            advanced += 1
            current = next

            guard next.time.lowerBoundWithFixed < range.upperBound else { break }
            if isInRange(next.time) {
                turns.append(next)
            }
        }
        return turns
    }
}


// MARK: - D-day 대상 조회 — 일정

private extension CalendarEventFetchUsecaseImple {

    func fetchDDayTargetSchedule(_ target: DDayTargetEventId) async -> DDayTargetEvent? {

        guard let schedule = await self.loadSchedule(target.rawId) else { return nil }

        guard let turnKey = target.turnKey else {
            return DDayTargetEvent(
                targetId: target,
                name: schedule.name,
                time: schedule.time,
                repeatOption: nil,
                repeatStartTime: nil
            )
        }

        guard let time = self.resolveTurnTime(schedule, turnKey: turnKey),
              let repeating = schedule.repeating
        else { return nil }

        return DDayTargetEvent(
            targetId: target,
            name: schedule.name,
            time: time,
            repeatOption: repeating.repeatOption,
            repeatStartTime: Date(
                timeIntervalSince1970: repeating.startTime(for: schedule.time)
            )
        )
    }

    func loadSchedule(_ id: String) async -> ScheduleEvent? {
        return try? await self.scheduleRepository.scheduleEvent(id)
            .values.first(where: { _ in true })
    }

    func makeEnumerator(_ schedule: ScheduleEvent) -> EventRepeatTimeEnumerator? {
        guard let repeating = schedule.repeating else { return nil }
        return EventRepeatTimeEnumerator(
            repeating.repeatOption,
            endOption: repeating.repeatingEndOption,
            without: schedule.repeatingTimeToExcludes
        )
    }

    /// 지정 회차(`customKey`)의 시각을 origin부터 전진해 찾는다.
    /// - 이넘레이터는 origin을 제외키와 대조하지 않으므로 먼저 직접 확인한다.
    /// - 반복이 그 회차 전에 끝나거나 키가 매칭되지 않으면 nil.
    /// - 원본 일정이 수정돼 회차 시각이 전부 밀리면 어떤 키와도 매칭되지 않는다. 열거는 시간순
    ///   전진이므로 목표 시각을 지난 순간 없는 회차로 확정하고 끊는다 — 상한까지 헛돌지 않게.
    func resolveTurnTime(_ schedule: ScheduleEvent, turnKey: String) -> EventTime? {

        guard !schedule.repeatingTimeToExcludes.contains(turnKey) else { return nil }
        guard schedule.time.customKey != turnKey else { return schedule.time }

        guard let repeating = schedule.repeating,
              let enumerator = self.makeEnumerator(schedule),
              let turnStartTime = EventTime.lowerBound(fromCustomKey: turnKey),
              schedule.time.lowerBoundWithFixed <= turnStartTime
        else { return nil }

        var current = RepeatingTimes(time: schedule.time, turn: 1)
        for _ in 0..<Constant.maxTurnAdvance {
            guard let next = enumerator.nextEventTime(
                from: current, until: repeating.repeatingEndOption?.endTime
            )
            else { return nil }
            if next.time.customKey == turnKey { return next.time }
            guard next.time.lowerBoundWithFixed < turnStartTime else { return nil }
            current = next
        }
        return nil
    }
}


// MARK: - D-day 대상 조회 — 공휴일

private extension CalendarEventFetchUsecaseImple {

    func fetchDDayTargetHoliday(_ target: DDayTargetEventId) async -> DDayTargetEvent? {

        guard let key = HolidayTargetKey(rawId: target.rawId),
              let yearRange = key.yearRange,
              await self.holidayFetchUsecase.currentCountryCode() == key.countryCode
        else { return nil }

        let holidays = (try? await self.holidayFetchUsecase.holidaysGivenYears(
            yearRange, timeZone: .current
        )) ?? []

        guard let holiday = self.matchHoliday(holidays, key),
              let event = HolidayCalendarEvent(holiday, in: .current),
              let time = event.eventTime
        else { return nil }

        return DDayTargetEvent(
            targetId: target,
            name: holiday.name,
            time: time,
            repeatOption: nil,
            repeatStartTime: nil
        )
    }

    /// name 우선 매칭. locale이 바뀌어 name이 안 맞으면 그 날 공휴일이 하나일 때만 확정한다.
    func matchHoliday(_ holidays: [Holiday], _ key: HolidayTargetKey) -> Holiday? {
        let sameDay = holidays.filter { $0.dateString == key.dateString }
        guard let byName = sameDay.first(where: { $0.name == key.name })
        else { return sameDay.count == 1 ? sameDay.first : nil }
        return byName
    }
}


private extension Array where Element == CalendarEvent {
    
    func sorted() -> Array {
        return self.sorted(by: { lhs, rhs in
            switch (lhs.eventTime?.lowerBoundWithFixed, rhs.eventTime?.lowerBoundWithFixed) {
            case (.none, .none): return true
            case (.none, .some): return false
            case (.some, .none): return true
            case (.some(let lt), .some(let rt)): return lt < rt
            }
        })
    }
}
