//
//  EventLiveActivityUsecaseImple.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import Prelude
import Optics
import Domain
import Extensions


/// 실제 액티비티 상태의 진실은 `controller.activityTargetUpdates`다 — 유저 스와이프 해제·
/// 시스템 8시간 상한 종료가 그 스트림으로만 감지되므로 `registeredTarget`도 그 값을 따라간다.
final class EventLiveActivityUsecaseImple: EventLiveActivityUsecase, @unchecked Sendable {

    private let controller: any LiveActivityController
    private let sharedDataStore: SharedDataStore
    private let eventDetailDataUsecase: any EventDetailDataUsecase

    init(
        controller: any LiveActivityController,
        sharedDataStore: SharedDataStore,
        eventDetailDataUsecase: any EventDetailDataUsecase
    ) {
        self.controller = controller
        self.sharedDataStore = sharedDataStore
        self.eventDetailDataUsecase = eventDetailDataUsecase
    }

    private struct Subject {
        let registeredTarget = CurrentValueSubject<LiveActivityTarget?, Never>(nil)
        let isReplacing = CurrentValueSubject<Bool, Never>(false)
    }

    private let subject = Subject()
    private var watchCancellable: AnyCancellable?
    private var externalUpdatesCancellable: AnyCancellable?
    private var pendingStart: Task<Void, any Error>?
}


// MARK: - command

extension EventLiveActivityUsecaseImple {

    /// 겹친 호출은 앞선 호출의 등록·교체가 끝난 뒤에 실행되도록 태스크로 직렬화한다 —
    /// 그래야 `subject.registeredTarget.value` 존재 여부로 하는 교체 판정이 유효하다.
    func startActivity(_ target: LiveActivityTarget) async throws {
        let now = Date()
        guard let observed = self.currentObservedEvent(for: target)
        else { throw EventLiveActivityStartFailReason.eventNotFound }
        try self.validateRegistration(eventDate: observed.eventDate, now: now)

        let detail = await self.eventDetail(for: target)
        let content = self.initialContent(from: observed, startDate: now, detail: detail)
        let baseline = LiveActivityBaseline(observed)

        let previous = self.pendingStart
        let task = Task { [weak self] in
            _ = try? await previous?.value
            try await self?.performStartActivity(target, content, baseline: baseline)
        }
        self.pendingStart = task
        try await task.value
    }

    /// 원격 상세 조회는 캐시가 없고 서버가 빈 응답을 주면 값도 완료도 보내지 않고 끝난다
    /// (`EventDetailUploadDecorateRepositoryImple`) — 타임아웃이 없으면 등록이 영영 매달린다.
    private func eventDetail(for target: LiveActivityTarget) async -> EventDetailData? {
        guard let id = target.eventDetailDataId else { return nil }
        return try? await self.eventDetailDataUsecase.loadDetail(id)
            .timeout(.seconds(Constant.detailLoadTimeout), scheduler: DispatchQueue.global())
            .values
            .first(where: { _ in true })
    }

    private func initialContent(
        from observed: LiveActivityObservedEvent,
        startDate: Date,
        detail: EventDetailData?
    ) -> EventCountdownActivityAttributes.State {
        return EventCountdownActivityAttributes.State(
            eventName: observed.name,
            eventTimeText: observed.eventTimeText,
            tagColorHex: observed.tagColorHex,
            eventDate: observed.eventDate,
            startDate: startDate,
            placeName: detail?.place?.placeName ?? observed.placeName,
            memo: detail?.memo
        )
    }

    private func validateRegistration(eventDate: Date, now: Date) throws {
        guard eventDate > now else { throw EventLiveActivityStartFailReason.alreadyPassed }
        guard eventDate <= now.addingTimeInterval(Constant.activeLimit)
        else { throw EventLiveActivityStartFailReason.tooFarFuture }
    }

    private func performStartActivity(
        _ target: LiveActivityTarget,
        _ content: EventCountdownActivityAttributes.State,
        baseline: LiveActivityBaseline
    ) async throws {
        self.subject.isReplacing.send(true)
        defer { self.subject.isReplacing.send(false) }

        if self.subject.registeredTarget.value != nil {
            await self.endCurrentActivity()
        }

        try await self.controller.startActivity(target, content)

        self.subject.registeredTarget.send(target)
        self.startWatching(target, seedContent: content, seedBaseline: baseline)
    }

    func stopActivity() async {
        guard self.subject.registeredTarget.value != nil else { return }
        await self.endCurrentActivity()
    }

    func prepare() async {
        self.controller.startObserving()
        self.bindExternalActivityUpdates()

        guard let registration = await self.controller.currentActivity()
        else {
            self.subject.registeredTarget.send(nil)
            return
        }
        guard await self.endIfExpired(registration) == false else { return }

        self.restore(registration)
    }

    /// 콜드런치 직후엔 ActivityKit이 `Activity.activities`를 아직 안 채워뒀을 수 있어 복귀마다
    /// 재조회한다. 이미 등록됐으면 재복원하지 않는다 — 감시 기준선이 리셋된다.
    func handleWillEnterForeground() async {
        guard let registration = await self.controller.currentActivity()
        else {
            self.clearRegistration()
            return
        }
        guard await self.endIfExpired(registration) == false else { return }
        guard self.subject.registeredTarget.value == nil else { return }

        self.restore(registration)
    }

    private func restore(_ registration: LiveActivityRegistration) {
        self.subject.registeredTarget.send(registration.target)
        self.startWatching(registration.target, seedContent: registration.content, seedBaseline: nil)
    }

    private func endIfExpired(_ registration: LiveActivityRegistration) async -> Bool {
        guard registration.content.eventDate <= Date() else { return false }
        await self.endCurrentActivity()
        return true
    }

    private func endCurrentActivity() async {
        await self.controller.endActivity()
        self.clearRegistration()
    }

    private func clearRegistration() {
        self.watchCancellable = nil
        self.subject.registeredTarget.send(nil)
    }

    /// 교체 흐름(종료 → 시작) 도중 도착한 controller의 stale nil은 무시한다 — 안 그러면
    /// 방금 끝낸 이전 액티비티의 뒤늦은 nil이 막 등록한 새 대상을 지운다.
    private func bindExternalActivityUpdates() {
        guard self.externalUpdatesCancellable == nil else { return }
        self.externalUpdatesCancellable = self.controller.activityTargetUpdates
            .dropFirst()
            .withLatestFrom(self.subject.isReplacing) { (aliveTarget: $0, isReplacing: $1) }
            .filter { $0.aliveTarget == nil && !$0.isReplacing }
            .sink { [weak self] _ in self?.clearRegistration() }
    }
}


// MARK: - query

extension EventLiveActivityUsecaseImple {

    var registeredTarget: AnyPublisher<LiveActivityTarget?, Never> {
        return self.subject.registeredTarget.eraseToAnyPublisher()
    }
}


// MARK: - 공유 상태 감시

extension EventLiveActivityUsecaseImple {

    /// 등록 경로는 조회 시점 관찰값을 기준선으로 넘긴다 — 첫 배달을 기다리면 그 사이 변화가
    /// 기준선에 흡수돼 파기 판정이 사라진다. 복원 경로는 넘길 값이 없어 nil(첫 non-nil 관찰값 채택)이다.
    private func startWatching(
        _ target: LiveActivityTarget,
        seedContent: EventCountdownActivityAttributes.State,
        seedBaseline: LiveActivityBaseline?
    ) {
        let initialState = LiveActivityWatchState(
            hasBaseline: seedBaseline != nil,
            baseline: seedBaseline ?? .init(),
            displayedContent: seedContent
        )

        self.watchCancellable = self.observedEventStream(for: target)
            .scan((initialState, LiveActivityJudgement.keep)) { [weak self] previous, observedRaw in
                guard let self else { return (previous.0, .keep) }
                return self.advanceWatchState(previous.0, target: target, observedRaw: observedRaw)
            }
            .sink { [weak self] result in
                self?.apply(result.1, for: target)
            }
    }

    /// 컨트롤러는 대상을 안 받고 살아있는 액티비티에 적용한다 — 판정 이후 교체가 끼어들면
    /// 옛 판정이 새 대상에 적용되므로, 실행 직전에 등록 대상이 그대로인지 확인한다.
    private func apply(_ judgement: LiveActivityJudgement, for target: LiveActivityTarget) {
        switch judgement {
        case .keep:
            break
        case .update(let content):
            Task { [weak self] in
                guard let self, self.subject.registeredTarget.value == target else { return }
                await self.controller.updateActivity(content)
            }
        case .end:
            Task { [weak self] in
                guard let self, self.subject.registeredTarget.value == target else { return }
                await self.endCurrentActivity()
            }
        }
    }

    /// 변화 신호와 조회를 나눠, 스트림 경로와 등록 시점의 단발 조회가 같은
    /// `currentObservedEvent(for:)`를 쓰게 한다.
    private func observedEventStream(
        for target: LiveActivityTarget
    ) -> AnyPublisher<LiveActivityObservedEvent?, Never> {
        return self.sourceChanges(for: target)
            .map { [weak self] _ in self?.currentObservedEvent(for: target) }
            .eraseToAnyPublisher()
    }

    private func sourceChanges(for target: LiveActivityTarget) -> AnyPublisher<Void, Never> {
        let store = self.sharedDataStore
        let eventChanges: AnyPublisher<Void, Never>
        switch target {
        case .todo:
            eventChanges = store
                .observe([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue)
                .map { _ in }.eraseToAnyPublisher()
        case .schedule:
            eventChanges = store
                .observe(MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue)
                .map { _ in }.eraseToAnyPublisher()
        case .holiday:
            eventChanges = store
                .observe(Holidays.self, key: ShareDataKeys.holidays.rawValue)
                .map { _ in }.eraseToAnyPublisher()
        case .googleCalendar:
            eventChanges = store
                .observe([String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue)
                .map { _ in }.eraseToAnyPublisher()
        case .appleCalendar:
            eventChanges = store
                .observe([String: AppleCalendar.Event].self, key: ShareDataKeys.appleCalendarEvents.rawValue)
                .map { _ in }.eraseToAnyPublisher()
        }

        return Publishers.CombineLatest(eventChanges, self.displayFormatChanges)
            .map { _ in }
            .eraseToAnyPublisher()
    }

    /// 시각 문구·공휴일 기준 시각 해석에 쓰는 설정 — 바뀌면 재판정이 돌아야 한다.
    private var displayFormatChanges: AnyPublisher<Void, Never> {
        return Publishers.CombineLatest(
            self.sharedDataStore.observe(TimeZone.self, key: ShareDataKeys.timeZone.rawValue),
            self.sharedDataStore.observe(
                CalendarAppearanceSettings.self, key: ShareDataKeys.calendarAppearance.rawValue
            )
        )
        .map { _ in }
        .eraseToAnyPublisher()
    }
}


// MARK: - 공유 상태 → 관찰 결과

extension EventLiveActivityUsecaseImple {

    private func currentObservedEvent(for target: LiveActivityTarget) -> LiveActivityObservedEvent? {
        let settings = self.currentDisplayFormatSettings()
        switch target {
        case .todo(let id):
            guard let todo = self.value([String: TodoEvent].self, .todos)?[id] else { return nil }
            return self.observedEvent(fromTodo: todo, settings: settings)

        case .schedule(let id, let turnKey):
            guard let schedule = self
                .value(MemorizedEventsContainer<ScheduleEvent>.self, .schedules)?.evnet(id)
            else { return nil }
            return self.observedEvent(fromSchedule: schedule, turnKey: turnKey, settings: settings)

        case .holiday(let uuid, _):
            guard let holiday = self.value(Holidays.self, .holidays)?
                .values.flatMap({ $0.values.flatMap { $0 } })
                .first(where: { $0.uuid == uuid })
            else { return nil }
            return self.observedEvent(fromHoliday: holiday, settings: settings)

        case .googleCalendar(let accountId, let calendarId, let eventId):
            guard let event = self
                .value([String: GoogleCalendar.Event].self, .googleCalendarEvents)?[eventId]
            else { return nil }
            return self.observedEvent(
                fromGoogle: event, accountId: accountId, calendarId: calendarId, settings: settings
            )

        case .appleCalendar(let calendarId, let eventId):
            guard let event = self
                .value([String: AppleCalendar.Event].self, .appleCalendarEvents)?[eventId]
            else { return nil }
            return self.observedEvent(fromApple: event, calendarId: calendarId, settings: settings)
        }
    }

    private func value<V>(_ type: V.Type, _ key: ShareDataKeys) -> V? {
        return self.sharedDataStore.value(type, key: key.rawValue)
    }

    private func currentDisplayFormatSettings() -> DisplayFormatSettings {
        return (
            timeZone: self.value(TimeZone.self, .timeZone) ?? .current,
            is24hourForm: self.value(CalendarAppearanceSettings.self, .calendarAppearance)?
                .is24hourForm ?? false
        )
    }

    private func observedEvent(
        fromTodo todo: TodoEvent, settings: DisplayFormatSettings
    ) -> LiveActivityObservedEvent? {
        guard let time = todo.time else { return nil }
        let eventDate = Date(timeIntervalSince1970: time.lowerBoundWithFixed)
        return LiveActivityObservedEvent(
            name: todo.name,
            eventDate: eventDate,
            eventTimeText: self.timeText(for: eventDate, settings: settings),
            tagColorHex: self.tagColorHex(for: todo.eventTagId),
            placeName: nil,
            repeatingTurn: todo.repeatingTurn,
            scheduleOriginTimeKey: nil,
            isTurnExcluded: false
        )
    }

    private func observedEvent(
        fromSchedule schedule: ScheduleEvent, turnKey: String?, settings: DisplayFormatSettings
    ) -> LiveActivityObservedEvent {
        let turnLowerBound = turnKey.flatMap { EventTime.lowerBound(fromCustomKey: $0) }
        let eventDate = Date(
            timeIntervalSince1970: turnLowerBound ?? schedule.time.lowerBoundWithFixed
        )
        return LiveActivityObservedEvent(
            name: schedule.name,
            eventDate: eventDate,
            eventTimeText: self.timeText(for: eventDate, settings: settings),
            tagColorHex: self.tagColorHex(for: schedule.eventTagId),
            placeName: nil,
            repeatingTurn: nil,
            scheduleOriginTimeKey: schedule.time.customKey,
            isTurnExcluded: turnKey.map { schedule.repeatingTimeToExcludes.contains($0) } ?? false
        )
    }

    private func observedEvent(
        fromHoliday holiday: Holiday, settings: DisplayFormatSettings
    ) -> LiveActivityObservedEvent? {
        guard let date = holiday.date(at: settings.timeZone) else { return nil }
        return LiveActivityObservedEvent(
            name: holiday.name,
            eventDate: date,
            eventTimeText: self.timeText(for: date, settings: settings),
            tagColorHex: self.defaultTagColors().holiday,
            placeName: nil,
            repeatingTurn: nil,
            scheduleOriginTimeKey: nil,
            isTurnExcluded: false
        )
    }

    private func observedEvent(
        fromGoogle event: GoogleCalendar.Event,
        accountId: String,
        calendarId: String,
        settings: DisplayFormatSettings
    ) -> LiveActivityObservedEvent {
        let eventDate = Date(timeIntervalSince1970: event.eventTime.lowerBoundWithFixed)
        let calendarTags = self.value([String: [GoogleCalendar.Tag]].self, .googleCalendarTags)
        let colorHex = calendarTags?[accountId]?.first { $0.id == calendarId }?.colorHex
        return LiveActivityObservedEvent(
            name: event.name,
            eventDate: eventDate,
            eventTimeText: self.timeText(for: eventDate, settings: settings),
            tagColorHex: colorHex ?? self.defaultTagColors().default,
            placeName: event.location,
            repeatingTurn: nil,
            scheduleOriginTimeKey: nil,
            isTurnExcluded: false
        )
    }

    private func observedEvent(
        fromApple event: AppleCalendar.Event, calendarId: String, settings: DisplayFormatSettings
    ) -> LiveActivityObservedEvent {
        let eventDate = Date(timeIntervalSince1970: event.eventTime.lowerBoundWithFixed)
        let colorHex = self.value([AppleCalendar.Tag].self, .appleCalendarTags)?
            .first { $0.id == calendarId }?.colorHex
        return LiveActivityObservedEvent(
            name: event.name,
            eventDate: eventDate,
            eventTimeText: self.timeText(for: eventDate, settings: settings),
            tagColorHex: colorHex ?? self.defaultTagColors().default,
            placeName: event.location,
            repeatingTurn: nil,
            scheduleOriginTimeKey: nil,
            isTurnExcluded: false
        )
    }

    private func timeText(for date: Date, settings: DisplayFormatSettings) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = settings.timeZone
        formatter.dateFormat = settings.is24hourForm
            ? "date_form::24on_H:mm".localized()
            : "date_form::a_h:mm".localized()
        return formatter.string(from: date)
    }

    private func defaultTagColors() -> DefaultEventTagColorSetting {
        return self.value(DefaultEventTagColorSetting.self, .defaultEventTagColor) ?? .default
    }

    private func tagColorHex(for tagId: EventTagId?) -> String {
        let defaults = self.defaultTagColors()
        switch tagId {
        case .holiday:
            return defaults.holiday
        case .custom, .externalCalendar:
            let tags = self.value([EventTagId: any EventTag].self, .tags)
            return tagId.flatMap { tags?[$0]?.colorHex } ?? defaults.default
        case .default, .none:
            return defaults.default
        }
    }
}


// MARK: - 판정

extension EventLiveActivityUsecaseImple {

    private func advanceWatchState(
        _ state: LiveActivityWatchState,
        target: LiveActivityTarget,
        observedRaw: LiveActivityObservedEvent?
    ) -> (LiveActivityWatchState, LiveActivityJudgement) {
        let observed = self.normalizedObserved(
            observedRaw, target: target, fallbackPlaceName: state.displayedContent.placeName
        )

        guard state.hasBaseline else {
            return (self.seededState(state, observed: observed), .keep)
        }

        let judgement = self.judge(
            observed: observed,
            baseline: state.baseline,
            displayedContent: state.displayedContent,
            now: Date()
        )
        return (self.advancedState(state, observed: observed, judgement: judgement), judgement)
    }

    /// 구독 즉시 흐르는 nil을 기준선으로 굳히면 뒤늦은 로드가 변경으로 오판된다.
    private func seededState(
        _ state: LiveActivityWatchState, observed: LiveActivityObservedEvent?
    ) -> LiveActivityWatchState {
        guard let observed else { return state }
        return state
            |> \.hasBaseline .~ true
            |> \.baseline .~ LiveActivityBaseline(observed)
    }

    private func advancedState(
        _ state: LiveActivityWatchState,
        observed: LiveActivityObservedEvent?,
        judgement: LiveActivityJudgement
    ) -> LiveActivityWatchState {
        let newContent: EventCountdownActivityAttributes.State
        if case .update(let content) = judgement {
            newContent = content
        } else {
            newContent = state.displayedContent
        }
        return state
            |> \.baseline.wasFound .~ (observed != nil)
            |> \.displayedContent .~ newContent
    }

    /// 판정 규칙 표(PR 본문 § 판정 규칙) 8행과 1:1로 대응한다.
    private func judge(
        observed: LiveActivityObservedEvent?,
        baseline: LiveActivityBaseline,
        displayedContent: EventCountdownActivityAttributes.State,
        now: Date
    ) -> LiveActivityJudgement {
        guard let observed else {
            return baseline.wasFound ? .end : .keep                                   // 규칙 1, 2
        }
        guard observed.repeatingTurn == baseline.repeatingTurn else { return .end }   // 규칙 3
        guard !observed.isTurnExcluded else { return .end }                           // 규칙 4
        guard observed.scheduleOriginTimeKey == baseline.scheduleOriginTimeKey
        else { return .end }                                                          // 규칙 5
        guard observed.eventDate > now,
              observed.eventDate <= now.addingTimeInterval(Constant.activeLimit)
        else { return .end }                                                          // 규칙 6
        guard observed.name == displayedContent.eventName,
              observed.eventDate == displayedContent.eventDate,
              observed.placeName == displayedContent.placeName
        else {
            return .update(self.updatedContent(displayedContent, observed: observed)) // 규칙 7
        }
        return .keep                                                                  // 규칙 8
    }

    private func updatedContent(
        _ base: EventCountdownActivityAttributes.State, observed: LiveActivityObservedEvent
    ) -> EventCountdownActivityAttributes.State {
        return base
            |> \.eventName .~ observed.name
            |> \.eventTimeText .~ observed.eventTimeText
            |> \.eventDate .~ observed.eventDate
            |> \.placeName .~ observed.placeName
    }

    /// Todo·Schedule·공휴일은 공유 상태에 장소 정보가 없다 — 규칙 7의 장소 비교 대상에서
    /// 제외하기 위해 현재 표시 중인 값을 그대로 흘려보낸다.
    private func normalizedObserved(
        _ observed: LiveActivityObservedEvent?, target: LiveActivityTarget, fallbackPlaceName: String?
    ) -> LiveActivityObservedEvent? {
        guard let observed, !target.supportsLocation else { return observed }
        return observed |> \.placeName .~ fallbackPlaceName
    }
}


// MARK: - 내부 타입

private enum Constant {
    static let activeLimit: TimeInterval = 8 * 3600
    static let detailLoadTimeout: TimeInterval = 1
}

private typealias Holidays = [String: [Int: [Holiday]]]
private typealias DisplayFormatSettings = (timeZone: TimeZone, is24hourForm: Bool)

private struct LiveActivityObservedEvent {
    var name: String
    var eventDate: Date
    var eventTimeText: String
    var tagColorHex: String
    var placeName: String?
    var repeatingTurn: Int?
    var scheduleOriginTimeKey: String?
    var isTurnExcluded: Bool
}

private struct LiveActivityBaseline {
    var repeatingTurn: Int?
    var scheduleOriginTimeKey: String?
    var wasFound: Bool = false

    init(_ observed: LiveActivityObservedEvent?) {
        self.repeatingTurn = observed?.repeatingTurn
        self.scheduleOriginTimeKey = observed?.scheduleOriginTimeKey
        self.wasFound = observed != nil
    }

    init() { }
}

private struct LiveActivityWatchState {
    var hasBaseline: Bool = false
    var baseline: LiveActivityBaseline = .init()
    var displayedContent: EventCountdownActivityAttributes.State
}

private enum LiveActivityJudgement {
    case keep
    case update(EventCountdownActivityAttributes.State)
    case end
}

private extension LiveActivityTarget {

    var supportsLocation: Bool {
        switch self {
        case .googleCalendar, .appleCalendar: return true
        case .todo, .schedule, .holiday: return false
        }
    }

    var eventDetailDataId: String? {
        switch self {
        case .todo(let id): return id
        case .schedule(let id, _): return id
        case .holiday, .googleCalendar, .appleCalendar: return nil
        }
    }
}
