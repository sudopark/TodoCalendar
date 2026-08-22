//
//  EventLiveActivityUsecaseImpleTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Foundation
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles
import Extensions

import Domain

@testable import TodoCalendarApp


final class EventLiveActivityUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeUsecase(
        stubRestoredRegistration: LiveActivityRegistration? = nil,
        stubStartError: (any Error)? = nil,
        stubEmitsNilOnEnd: Bool = false,
        stubStartDelayNanoseconds: UInt64 = 0,
        eventDetailUsecase: SpyEventDetailDataUsecase = .init()
    ) -> (EventLiveActivityUsecaseImple, StubLiveActivityController, SharedDataStore) {
        let stub = StubLiveActivityController(
            stubRestoredRegistration: stubRestoredRegistration,
            stubStartError: stubStartError,
            stubEmitsNilOnEnd: stubEmitsNilOnEnd,
            stubStartDelayNanoseconds: stubStartDelayNanoseconds
        )
        let store = SharedDataStore()
        let usecase = EventLiveActivityUsecaseImple(
            controller: stub,
            sharedDataStore: store,
            eventDetailDataUsecase: eventDetailUsecase
        )
        return (usecase, stub, store)
    }

    /// `eventDate`는 store 왕복(`EventTime.at` → `Date(timeIntervalSince1970:)`)을 거친 값과
    /// 비트 단위로 같아야 판정 비교(`==`)가 안정적이다 — 여기서도 동일 왕복을 미리 거친다.
    private func content(
        name: String = "event",
        eventDate: Date,
        startDate: Date? = nil,
        place: String? = nil
    ) -> EventCountdownActivityAttributes.State {
        let canonicalEventDate = Date(timeIntervalSince1970: eventDate.timeIntervalSince1970)
        return EventCountdownActivityAttributes.State(
            eventName: name,
            eventTimeText: "text",
            tagColorHex: "#000000",
            eventDate: canonicalEventDate,
            startDate: startDate ?? canonicalEventDate,
            placeName: place
        )
    }

    private func makeTodo(
        id: String, name: String = "todo", eventDate: Date, turn: Int? = nil
    ) -> TodoEvent {
        return TodoEvent(uuid: id, name: name)
            |> \.time .~ .at(eventDate.timeIntervalSince1970)
            |> \.repeatingTurn .~ turn
    }

    private func makeSchedule(
        id: String, name: String = "schedule", eventDate: Date, excludes: Set<String> = []
    ) -> ScheduleEvent {
        return ScheduleEvent(uuid: id, name: name, time: .at(eventDate.timeIntervalSince1970))
            |> \.repeatingTimeToExcludes .~ excludes
    }

    private func makeGoogleEvent(
        id: String, calendarId: String = "cal", accountId: String = "acc",
        name: String = "google", colorId: String? = nil, eventDate: Date, location: String? = nil
    ) -> GoogleCalendar.Event {
        return GoogleCalendar.Event(
            id, calendarId, accountId: accountId, name: name, colorId: colorId,
            location: location, time: .at(eventDate.timeIntervalSince1970)
        )
    }

    private func makeAppleEvent(
        id: String, calendarId: String = "cal", name: String = "apple",
        eventDate: Date, location: String? = nil
    ) -> AppleCalendar.Event {
        return AppleCalendar.Event(
            eventId: id, originalEventId: id, calendarId: calendarId,
            name: name, eventTime: .at(eventDate.timeIntervalSince1970)
        )
        |> \.location .~ location
    }

    private func putTodos(_ store: SharedDataStore, _ todos: [TodoEvent]) {
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            todos.reduce(into: [:]) { $0[$1.uuid] = $1 }
        )
    }

    private func expectedTimeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = .current
        formatter.dateFormat = "date_form::a_h:mm".localized()
        return formatter.string(from: date)
    }

    private func waitForEffects() async throws {
        try await Task.sleep(for: .milliseconds(100))
    }

    /// 실행 시각과 무관하게 항상 `(now, now+8h)` 안에 들어오는 공휴일 시나리오를 만든다 —
    /// `dateString`(일 단위)이 정확히 `now + aheadHours`를 자정으로 갖도록 커스텀 오프셋
    /// 타임존을 역산한다. `resolvedDate`는 그 타임존으로 `Holiday.date(at:)`를 호출한
    /// 결과 그 자체라 프로덕션과 같은 계산으로 비교값을 얻는다.
    private func holidayTimeZoneScenario(
        aheadHours: Double = 3
    ) -> (dateString: String, timeZone: TimeZone, resolvedDate: Date) {
        let target = Date().addingTimeInterval(aheadHours * 3600)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let dayStart = utcCalendar.startOfDay(for: target)
        var offsetSeconds = Int(dayStart.timeIntervalSince(target))
        var dayForString = dayStart
        if offsetSeconds < -18 * 3600 {
            offsetSeconds += 24 * 3600
            dayForString = utcCalendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        }

        let timeZone = TimeZone(secondsFromGMT: offsetSeconds) ?? .current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = utcCalendar.timeZone
        let dateString = formatter.string(from: dayForString)
        let holiday = Holiday(uuid: "hz", dateString: dateString, name: "holiday")
        let resolvedDate = holiday.date(at: timeZone) ?? target
        return (dateString, timeZone, resolvedDate)
    }
}


// MARK: - 등록 판정

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_whenEventDateIsPast_throwsAlreadyPassed() async throws {
        // given
        let (usecase, _, store) = self.makeUsecase()
        let past = Date().addingTimeInterval(-10)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: past)])

        // when
        var caught: EventLiveActivityStartFailReason?
        do {
            try await usecase.startActivity(.todo(id: "t1"))
        } catch let error as EventLiveActivityStartFailReason {
            caught = error
        }

        // then
        #expect(caught == .alreadyPassed)
    }

    @Test func usecase_whenEventDateIsBeyond8Hours_throwsTooFarFuture() async throws {
        // given
        let (usecase, _, store) = self.makeUsecase()
        let farFuture = Date().addingTimeInterval(8 * 3600 + 1)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: farFuture)])

        // when
        var caught: EventLiveActivityStartFailReason?
        do {
            try await usecase.startActivity(.todo(id: "t1"))
        } catch let error as EventLiveActivityStartFailReason {
            caught = error
        }

        // then
        #expect(caught == .tooFarFuture)
    }

    @Test func usecase_whenEventDateIsExactly8Hours_startsActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let exactly8h = Date().addingTimeInterval(8 * 3600)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: exactly8h)])

        // when
        try await usecase.startActivity(.todo(id: "t1"))

        // then
        #expect(stub.didStartWith?.0 == .todo(id: "t1"))
    }

    @Test func usecase_whenStartFails_doesNotChangeRegisteredTarget() async throws {
        // given
        let (usecase, _, store) = self.makeUsecase(stubStartError: TestError())
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])

        // when
        _ = try? await usecase.startActivity(.todo(id: "t1"))

        // then
        let expect = self.expectConfirm("registeredTarget stays nil")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .some(nil))
    }
}


// MARK: - 교체·종료

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_whenStartingWhileAnotherIsActive_endsPreviousThenStarts() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [
            self.makeTodo(id: "t1", eventDate: future), self.makeTodo(id: "t2", eventDate: future)
        ])
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        try await usecase.startActivity(.todo(id: "t2"))

        // then
        #expect(stub.didEnd == true)
        #expect(stub.didStartWith?.0 == .todo(id: "t2"))
        let expect = self.expectConfirm("registered target replaced")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .todo(id: "t2"))
    }

    @Test func usecase_stopActivity_endsAndClearsRegisteredTarget() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        await usecase.stopActivity()

        // then
        #expect(stub.didEnd == true)
        let expect = self.expectConfirm("registered target cleared")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .some(nil))
    }

    /// F3 회귀 — 이전 액티비티 종료가 시스템에 자신의 종료를 nil로 알리는 것과 새 등록이
    /// 겹칠 때, 그 stale nil이 별도의 `clearRegistration()` 호출을 더 일으키면 안 된다.
    @Test func usecase_whenReplacingActivity_ignoresStaleNilFromController() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase(stubEmitsNilOnEnd: true)
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [
            self.makeTodo(id: "t1", eventDate: future), self.makeTodo(id: "t2", eventDate: future)
        ])
        await usecase.prepare()
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let expect = self.expectConfirm("교체 중 stale nil은 추가 방출을 만들지 않는다")
        expect.count = 3
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            try await usecase.startActivity(.todo(id: "t2"))
        }

        // then
        #expect(stub.didEnd == true)
        #expect(targets == [.todo(id: "t1"), nil, .todo(id: "t2")])
    }

    /// I-3 회귀 — 첫 `startActivity`가 컨트롤러 호출 중(지연)일 때 두 번째 `startActivity`가
    /// 겹쳐 들어오면, 직렬화가 없으면 둘 다 `registeredTargetSubject.value`를 nil로 관찰해
    /// 교체 종료(`endActivity`)를 건너뛴 채 각자 등록만 한다 — 가드를 되돌리면 `didEnd`가
    /// `false`로 빨개진다.
    @Test func usecase_whenStartActivityCallsOverlap_serializesReplacement() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase(stubStartDelayNanoseconds: 50_000_000)
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [
            self.makeTodo(id: "t1", eventDate: future), self.makeTodo(id: "t2", eventDate: future)
        ])

        // when
        async let first: () = try usecase.startActivity(.todo(id: "t1"))
        try await Task.sleep(nanoseconds: 5_000_000)
        async let second: () = try usecase.startActivity(.todo(id: "t2"))
        _ = try await (first, second)

        // then
        #expect(stub.didEnd == true)
        #expect(stub.didStartWith?.0 == .todo(id: "t2"))
        let expect = self.expectConfirm("겹친 시작 후 최신 대상만 남는다")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .todo(id: "t2"))
    }
}


// MARK: - 판정 규칙 1, 2 — 존재 여부

extension EventLiveActivityUsecaseImpleTests {

    /// 등록은 공유 상태에 대상이 있어야 성립하므로, "한 번도 못 찾음"은 복원 경로에서만
    /// 생긴다 — 콜드런치 직후 캐시가 비어 있어도 살아있는 액티비티를 끄면 안 된다.
    @Test func usecase_afterRestore_whenTargetNeverAppearedInStore_keepsActivity() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "missing"), content: self.content(eventDate: future)
        )
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: registration)
        await usecase.prepare()

        // when
        store.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, [:])
        try await self.waitForEffects()

        // then
        #expect(stub.didEnd == false)
    }

    @Test func usecase_whenTargetDisappearsFromStore_endsActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future)]
        )
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let expect = self.expectConfirm("대상 삭제 시 종료")
        expect.count = 2
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            store.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, [:])
        }

        // then
        #expect(targets.last == .some(nil))
        #expect(stub.didEnd == true)
    }
}


// MARK: - 판정 규칙 3, 4, 5 — 반복 회차·시리즈 변화

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_whenTodoRepeatingTurnChanges_endsActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future, turn: nil)]
        )
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let expect = self.expectConfirm("반복 turn 변화 시 종료")
        expect.count = 2
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            store.put(
                [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
                ["t1": self.makeTodo(id: "t1", eventDate: future.addingTimeInterval(3600), turn: 2)]
            )
        }

        // then
        #expect(targets.last == .some(nil))
        #expect(stub.didEnd == true)
    }

    @Test func usecase_whenScheduleTurnKeyIsExcluded_endsActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        let turnKey = EventTime.at(future.timeIntervalSince1970).customKey
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>().append(self.makeSchedule(id: "s1", eventDate: future))
        )
        try await usecase.startActivity(.schedule(id: "s1", turnKey: turnKey))

        // when
        let expect = self.expectConfirm("회차 제외 시 종료")
        expect.count = 2
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            store.put(
                MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
                MemorizedEventsContainer<ScheduleEvent>()
                    .append(self.makeSchedule(id: "s1", eventDate: future, excludes: [turnKey]))
            )
        }

        // then
        #expect(targets.last == .some(nil))
        #expect(stub.didEnd == true)
    }

    @Test func usecase_whenScheduleOriginTimeChanges_endsActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>().append(self.makeSchedule(id: "s1", eventDate: future))
        )
        try await usecase.startActivity(.schedule(id: "s1", turnKey: nil))

        // when
        let expect = self.expectConfirm("시리즈 시각 변경 시 종료")
        expect.count = 2
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            store.put(
                MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
                MemorizedEventsContainer<ScheduleEvent>()
                    .append(self.makeSchedule(id: "s1", eventDate: future.addingTimeInterval(1800)))
            )
        }

        // then
        #expect(targets.last == .some(nil))
        #expect(stub.didEnd == true)
    }
}


// MARK: - 판정 규칙 6 — 등록 조건 파기

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_whenUpdatedEventDateIsPast_endsActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future)]
        )
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let expect = self.expectConfirm("과거로 변경되면 종료")
        expect.count = 2
        let past = Date().addingTimeInterval(-60)
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            store.put(
                [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
                ["t1": self.makeTodo(id: "t1", eventDate: past)]
            )
        }

        // then
        #expect(targets.last == .some(nil))
        #expect(stub.didEnd == true)
    }

    @Test func usecase_whenUpdatedEventDateExceeds8Hours_endsActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future)]
        )
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let expect = self.expectConfirm("8시간 초과로 변경되면 종료")
        expect.count = 2
        let farFuture = Date().addingTimeInterval(9 * 3600)
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            store.put(
                [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
                ["t1": self.makeTodo(id: "t1", eventDate: farFuture)]
            )
        }

        // then
        #expect(targets.last == .some(nil))
        #expect(stub.didEnd == true)
    }
}


// MARK: - 판정 규칙 7, 8 — 표시 내용 갱신

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_whenEventNameChanges_updatesActivityContent() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", name: "old", eventDate: future)]
        )
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", name: "new", eventDate: future)]
        )
        try await self.waitForEffects()

        // then
        #expect(stub.didUpdateWith?.eventName == "new")
    }

    @Test func usecase_whenUpdatedEventDateStillWithin8Hours_updatesActivityContent() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future)]
        )
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let nextTime = future.addingTimeInterval(3600)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: nextTime)]
        )
        try await self.waitForEffects()

        // then
        #expect(stub.didUpdateWith?.eventDate == Date(timeIntervalSince1970: nextTime.timeIntervalSince1970))
    }

    /// I-1 회귀 — `eventDate`가 바뀌어 규칙 7이 갱신을 낼 때 `eventTimeText`도 새 시각
    /// 기준으로 재계산돼야 한다. 옛 문자열을 그대로 흘리면 이 단언이 빨개진다.
    @Test func usecase_whenUpdatedEventDateStillWithin8Hours_recomputesEventTimeText() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future)]
        )
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let nextTime = future.addingTimeInterval(3600)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: nextTime)]
        )
        try await self.waitForEffects()

        // then
        let expectedText = self.expectedTimeText(
            for: Date(timeIntervalSince1970: nextTime.timeIntervalSince1970)
        )
        #expect(stub.didUpdateWith?.eventTimeText == expectedText)
    }

    @Test func usecase_whenGoogleEventLocationChanges_updatesActivityContent() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", eventDate: future, location: "old place")]
        )
        try await usecase.startActivity(.googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1"))

        // when
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", eventDate: future, location: "new place")]
        )
        try await self.waitForEffects()

        // then
        #expect(stub.didUpdateWith?.placeName == "new place")
    }

    @Test func usecase_whenNothingChanges_doesNotUpdateActivity() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        let todo = self.makeTodo(id: "t1", name: "same", eventDate: future)
        store.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, ["t1": todo])
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        store.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, ["t1": todo])
        try await self.waitForEffects()

        // then
        #expect(stub.didUpdateWith == nil)
        #expect(stub.didEnd == false)
    }

    @Test func usecase_whenUpdatingContent_keepsOriginalStartDate() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future)]
        )
        try await usecase.startActivity(.todo(id: "t1"))
        let startDate = try #require(stub.didStartWith?.1.startDate)

        // when
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", name: "changed", eventDate: future)]
        )
        try await self.waitForEffects()

        // then
        #expect(stub.didUpdateWith?.startDate == startDate)
    }
}


// MARK: - 복원·만료

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_prepare_restoresRegisteredTargetFromController() async throws {
        // given
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: Date().addingTimeInterval(60))
        )
        let (usecase, _, _) = self.makeUsecase(stubRestoredRegistration: registration)

        // when
        await usecase.prepare()

        // then
        let expect = self.expectConfirm("restored target reflected")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .todo(id: "t1"))
    }

    /// 컨트롤러의 ActivityKit 관찰은 의존성 조립 시점이 아니라 `prepare()`에서 붙는다 —
    /// init에서 붙이면 앱이 준비되기 전에 async sequence가 돌기 시작한다.
    @Test func usecase_prepare_startsControllerObserving() async throws {
        // given
        let (usecase, stub, _) = self.makeUsecase()
        #expect(stub.didStartObserving == false)

        // when
        await usecase.prepare()

        // then
        #expect(stub.didStartObserving == true)
    }

    @Test func usecase_prepare_whenNoActivityExists_leavesRegisteredTargetNil() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase(stubRestoredRegistration: nil)

        // when
        await usecase.prepare()

        // then
        let expect = self.expectConfirm("no target to restore")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .some(nil))
    }

    /// M-2 회귀 — 콜드런치 시점에 복원 대상의 표시 시각이 이미 지났으면 감시를 시작하지
    /// 않고 즉시 종료한다. `willEnterForeground`는 콜드런치엔 안 오므로 여기서 안 끊으면
    /// 만료된 액티비티가 유저가 백그라운드→포그라운드를 왕복할 때까지 남는다.
    @Test func usecase_prepare_whenRestoredActivityAlreadyExpired_endsImmediately() async throws {
        // given
        let past = Date().addingTimeInterval(-60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: past)
        )
        let (usecase, stub, _) = self.makeUsecase(stubRestoredRegistration: registration)

        // when
        await usecase.prepare()

        // then
        #expect(stub.didEnd == true)
        let expect = self.expectConfirm("만료된 복원 대상 즉시 종료")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .some(nil))
    }

    /// F1 회귀 — 복원 seed는 controller가 돌려준 실제 content여야 한다. 자리표시자로
    /// 시작했다면 `tagColorHex`·`startDate`가 빈 값/`.distantPast`로 새어나온다. `eventTimeText`는
    /// I-1 이후 갱신마다 관찰된 시각 기준으로 재계산되므로 seed 값이 아니라 재계산값과 비교한다.
    @Test func usecase_prepare_restoresDisplayedContentFromController() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let restoredContent = EventCountdownActivityAttributes.State(
            eventName: "restored", eventTimeText: "restored-text", tagColorHex: "#ABCDEF",
            eventDate: future, startDate: future.addingTimeInterval(-1800)
        )
        let registration = LiveActivityRegistration(target: .todo(id: "t1"), content: restoredContent)
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: registration)
        await usecase.prepare()
        try await self.waitForEffects()
        self.putTodos(store, [self.makeTodo(id: "t1", name: "restored", eventDate: future)])
        try await self.waitForEffects()

        // when
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", name: "changed", eventDate: future)]
        )
        try await self.waitForEffects()

        // then
        let expectedTimeText = self.expectedTimeText(
            for: Date(timeIntervalSince1970: future.timeIntervalSince1970)
        )
        #expect(stub.didUpdateWith?.eventTimeText == expectedTimeText)
        #expect(stub.didUpdateWith?.tagColorHex == "#ABCDEF")
        #expect(stub.didUpdateWith?.startDate == restoredContent.startDate)
    }

    @Test func usecase_afterRestore_usesFirstObservedValueAsBaseline() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: registration)
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", eventDate: future, turn: 3)]
        )

        // when
        await usecase.prepare()
        try await self.waitForEffects()

        // then
        #expect(stub.didEnd == false)
        #expect(stub.didUpdateWith == nil)
    }

    /// 복원 기준선은 첫 관찰값으로 잡혀 규칙 5가 안 끊는다 — 규칙 7 갱신에서 회차 쿼리도
    /// 복원 시점 값이 아니라 관찰된 새 시각을 따라가야 한다.
    @Test func usecase_afterRestore_whenRuleSevenFires_updatesScheduleTimeQuery() async throws {
        // given
        let staleTime = Date().addingTimeInterval(60)
        let newTime = Date().addingTimeInterval(120)
        let staleContent = self.content(name: "schedule", eventDate: staleTime)
            |> \.scheduleTimeQuery .~ EventTime.at(staleTime.timeIntervalSince1970).queryParams
        let registration = LiveActivityRegistration(
            target: .schedule(id: "s1", turnKey: nil), content: staleContent
        )
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: registration)
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>()
                .append(self.makeSchedule(id: "s1", name: "schedule", eventDate: newTime))
        )
        await usecase.prepare()
        try await self.waitForEffects()

        // when
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>()
                .append(self.makeSchedule(id: "s1", name: "changed", eventDate: newTime))
        )
        try await self.waitForEffects()

        // then
        let expectedQuery = EventTime.at(newTime.timeIntervalSince1970).queryParams
        #expect(stub.didUpdateWith?.scheduleTimeQuery == expectedQuery)
    }

    @Test func usecase_handleWillEnterForeground_whenEventDatePassed_endsActivity() async throws {
        // given
        let past = Date().addingTimeInterval(-60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: past)
        )
        let (usecase, stub, _) = self.makeUsecase(stubRestoredRegistration: registration)
        await usecase.prepare()
        try await self.waitForEffects()

        // when
        await usecase.handleWillEnterForeground()

        // then
        #expect(stub.didEnd == true)
        let expect = self.expectConfirm("만료된 액티비티 종료")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .some(nil))
    }

    @Test func usecase_handleWillEnterForeground_whenEventDateStillFuture_keepsActivity() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        let (usecase, stub, _) = self.makeUsecase(stubRestoredRegistration: registration)
        await usecase.prepare()
        try await self.waitForEffects()

        // when
        await usecase.handleWillEnterForeground()

        // then
        #expect(stub.didEnd == false)
    }

    /// F1 회귀 — 복원 직후 공유 상태가 아직 안 채워진 상태(콜드스타트 직후 주 사용 동선)에서
    /// 포그라운드 진입해도, 자리표시자가 없으니 살아있는 액티비티를 잘못 종료하지 않는다.
    @Test func usecase_afterRestore_whenStoreHasNoEntry_handleWillEnterForegroundKeepsActivity() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        let (usecase, stub, _) = self.makeUsecase(stubRestoredRegistration: registration)

        // when
        await usecase.prepare()
        try await self.waitForEffects()
        await usecase.handleWillEnterForeground()

        // then
        #expect(stub.didEnd == false)
    }

    /// F3 회귀 — 앱 서스펜드 중 잠금화면 해제는 async sequence로 배달 보장이 없다. 포그라운드
    /// 복귀 시 `controller.currentActivity()`로 재조정해 stale 등록을 정리한다.
    @Test func usecase_handleWillEnterForeground_whenActivityGoneWhileSuspended_clearsRegisteredTarget() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: nil)
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        await usecase.handleWillEnterForeground()

        // then
        #expect(stub.didEnd == false)
        let expect = self.expectConfirm("재조정으로 등록 해제")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .some(nil))
    }

    @Test func usecase_handleWillEnterForeground_whenActivityStillAlive_keepsRegisteredTarget() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let stillAlive = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: stillAlive)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        await usecase.handleWillEnterForeground()

        // then
        #expect(stub.didCheckCurrentActivity == true)
        #expect(stub.didEnd == false)
        let expect = self.expectConfirm("재조정이 멀쩡한 등록을 유지한다")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .todo(id: "t1"))
    }

    @Test func usecase_whenSystemDismissesActivity_clearsRegisteredTarget() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])
        await usecase.prepare()
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        let expect = self.expectConfirm("시스템 해제 시 등록 해제")
        expect.count = 2
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            stub.activityTargetUpdatesSubject.send(nil)
        }

        // then
        #expect(targets.last == .some(nil))
    }

    @Test func usecase_afterSystemDismissal_doesNotUpdateActivityOnStoreChange() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", name: "old", eventDate: future)])
        await usecase.prepare()
        try await usecase.startActivity(.todo(id: "t1"))
        let expect = self.expectConfirm("시스템 해제 대기")
        expect.count = 2
        _ = try await self.outputs(expect, for: usecase.registeredTarget) {
            stub.activityTargetUpdatesSubject.send(nil)
        }

        // when
        store.put(
            [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
            ["t1": self.makeTodo(id: "t1", name: "new", eventDate: future)]
        )
        try await self.waitForEffects()

        // then
        #expect(stub.didUpdateWith == nil)
    }
}


// MARK: - 앱 재시작 복원 재시도

extension EventLiveActivityUsecaseImpleTests {

    /// 콜드런치 직후엔 `Activity.activities`가 아직 비어 있을 수 있다.
    @Test func usecase_whenActivityNotVisibleAtColdLaunch_handleWillEnterForegroundRestoresTarget() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let (usecase, stub, _) = self.makeUsecase(stubRestoredRegistration: nil)
        await usecase.prepare()
        try await self.waitForEffects()

        // when
        stub.stubRestoredRegistration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        await usecase.handleWillEnterForeground()

        // then
        let expect = self.expectConfirm("뒤늦게 보인 액티비티 복원")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .todo(id: "t1"))
    }

    @Test func usecase_whenRestoredOnForeground_watchesSharedStateChanges() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: nil)
        await usecase.prepare()
        try await self.waitForEffects()
        stub.stubRestoredRegistration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        await usecase.handleWillEnterForeground()
        self.putTodos(store, [self.makeTodo(id: "t1", name: "event", eventDate: future)])
        try await self.waitForEffects()

        // when
        self.putTodos(store, [self.makeTodo(id: "t1", name: "changed", eventDate: future)])
        try await self.waitForEffects()

        // then
        #expect(stub.didUpdateWith?.eventName == "changed")
    }

    @Test func usecase_whenActivityRestoredOnForegroundAlreadyExpired_endsImmediately() async throws {
        // given
        let past = Date().addingTimeInterval(-60)
        let (usecase, stub, _) = self.makeUsecase(stubRestoredRegistration: nil)
        await usecase.prepare()
        try await self.waitForEffects()

        // when
        stub.stubRestoredRegistration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: past)
        )
        await usecase.handleWillEnterForeground()

        // then
        #expect(stub.didEnd == true)
        let expect = self.expectConfirm("만료된 액티비티는 복원 대신 종료")
        let target = try await self.firstOutput(expect, for: usecase.registeredTarget)
        #expect(target == .some(nil))
    }

    /// 재복원은 기준선을 리셋해 그 사이 바뀐 회차를 흡수해버린다.
    @Test func usecase_handleWillEnterForeground_whenAlreadyRegistered_keepsExistingBaseline() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let (usecase, stub, store) = self.makeUsecase()
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])
        try await usecase.startActivity(.todo(id: "t1"))
        stub.stubRestoredRegistration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )

        // when
        await usecase.handleWillEnterForeground()
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future, turn: 3)])
        try await self.waitForEffects()

        // then
        #expect(stub.didEnd == true)
    }
}


// MARK: - 복원 기준선 시딩

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_afterRestore_whenScheduleLoadsLater_keepsActivity() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let registration = LiveActivityRegistration(
            target: .schedule(id: "s1", turnKey: nil), content: self.content(eventDate: future)
        )
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: registration)
        await usecase.prepare()
        try await self.waitForEffects()

        // when
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>().append(self.makeSchedule(id: "s1", eventDate: future))
        )
        try await self.waitForEffects()

        // then
        #expect(stub.didEnd == false)
    }

    @Test func usecase_afterRestore_whenRepeatingTodoLoadsLater_keepsActivity() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: registration)
        await usecase.prepare()
        try await self.waitForEffects()

        // when
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future, turn: 3)])
        try await self.waitForEffects()

        // then
        #expect(stub.didEnd == false)
    }

    @Test func usecase_afterRestore_whenTurnChangesAfterBaselineSeeded_endsActivity() async throws {
        // given
        let future = Date().addingTimeInterval(60)
        let registration = LiveActivityRegistration(
            target: .todo(id: "t1"), content: self.content(eventDate: future)
        )
        let (usecase, stub, store) = self.makeUsecase(stubRestoredRegistration: registration)
        await usecase.prepare()
        try await self.waitForEffects()
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future, turn: 3)])
        try await self.waitForEffects()

        // when
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future, turn: 4)])
        try await self.waitForEffects()

        // then
        #expect(stub.didEnd == true)
    }
}


// MARK: - 5종 대상 구독 배선

extension EventLiveActivityUsecaseImpleTests {

    enum TargetKindCase: String, CaseIterable, Sendable {
        case todo, schedule, holiday, google, apple
    }

    private func target(for kind: TargetKindCase, holidayDateString: String) -> LiveActivityTarget {
        switch kind {
        case .todo: return .todo(id: "id1")
        case .schedule: return .schedule(id: "id1", turnKey: nil)
        case .holiday: return .holiday(uuid: "id1", dateString: holidayDateString)
        case .google: return .googleCalendar(accountId: "a1", calendarId: "c1", eventId: "id1")
        case .apple: return .appleCalendar(calendarId: "c1", eventId: "id1")
        }
    }

    private func seedStore(
        _ store: SharedDataStore, kind: TargetKindCase, eventDate: Date, holidayDateString: String
    ) {
        switch kind {
        case .todo:
            store.put(
                [String: TodoEvent].self, key: ShareDataKeys.todos.rawValue,
                ["id1": self.makeTodo(id: "id1", eventDate: eventDate)]
            )
        case .schedule:
            store.put(
                MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
                MemorizedEventsContainer<ScheduleEvent>()
                    .append(self.makeSchedule(id: "id1", eventDate: eventDate))
            )
        case .holiday:
            store.put(
                [String: [Int: [Holiday]]].self, key: ShareDataKeys.holidays.rawValue,
                ["KR": [2026: [Holiday(uuid: "id1", dateString: holidayDateString, name: "holiday")]]]
            )
        case .google:
            store.put(
                [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
                ["id1": self.makeGoogleEvent(id: "id1", eventDate: eventDate)]
            )
        case .apple:
            store.put(
                [String: AppleCalendar.Event].self, key: ShareDataKeys.appleCalendarEvents.rawValue,
                ["id1": self.makeAppleEvent(id: "id1", eventDate: eventDate)]
            )
        }
    }

    private func clearStore(_ store: SharedDataStore, kind: TargetKindCase) {
        switch kind {
        case .todo:
            store.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, [:])
        case .schedule:
            store.put(
                MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
                .init()
            )
        case .holiday:
            store.put([String: [Int: [Holiday]]].self, key: ShareDataKeys.holidays.rawValue, [:])
        case .google:
            store.put([String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue, [:])
        case .apple:
            store.put([String: AppleCalendar.Event].self, key: ShareDataKeys.appleCalendarEvents.rawValue, [:])
        }
    }

    @Test(
        "5종 대상 각각 공유 상태 구독이 붙는다",
        arguments: TargetKindCase.allCases
    )
    func usecase_observesStore_forEachTargetKind(_ kind: TargetKindCase) async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        let scenario = self.holidayTimeZoneScenario()
        store.put(TimeZone.self, key: ShareDataKeys.timeZone.rawValue, scenario.timeZone)
        let liveTarget = self.target(for: kind, holidayDateString: scenario.dateString)
        self.seedStore(
            store, kind: kind, eventDate: future, holidayDateString: scenario.dateString
        )
        try await usecase.startActivity(liveTarget)

        // when
        let expect = self.expectConfirm("\(kind.rawValue) 대상 삭제 시 종료")
        expect.count = 2
        let targets = try await self.outputs(expect, for: usecase.registeredTarget) {
            self.clearStore(store, kind: kind)
        }

        // then
        #expect(targets.last == .some(nil))
        #expect(stub.didEnd == true)
    }
}


// MARK: - 공휴일 타임존 해석

extension EventLiveActivityUsecaseImpleTests {

    /// I-2 회귀 — 공휴일 기준 시각은 공유 상태의 타임존(`ShareDataKeys.timeZone`)으로
    /// 해석해야 한다. `Holiday.date(at:)`를 `.current`로 되돌리면 이 단언이 빨개진다.
    @Test func usecase_holidayTarget_resolvesEventDateUsingSharedTimeZone() async throws {
        // given
        let scenario = self.holidayTimeZoneScenario()
        let (usecase, stub, store) = self.makeUsecase()
        store.put(TimeZone.self, key: ShareDataKeys.timeZone.rawValue, scenario.timeZone)
        store.put(
            [String: [Int: [Holiday]]].self, key: ShareDataKeys.holidays.rawValue,
            ["KR": [2026: [Holiday(uuid: "hz", dateString: scenario.dateString, name: "old")]]]
        )
        try await usecase.startActivity(.holiday(uuid: "hz", dateString: scenario.dateString))

        // when
        store.put(
            [String: [Int: [Holiday]]].self, key: ShareDataKeys.holidays.rawValue,
            ["KR": [2026: [Holiday(uuid: "hz", dateString: scenario.dateString, name: "new")]]]
        )
        try await self.waitForEffects()

        // then
        #expect(stub.didEnd == false)
        #expect(stub.didUpdateWith?.eventName == "new")
        #expect(stub.didUpdateWith?.eventDate == scenario.resolvedDate)
    }
}


// MARK: - 등록 시 표시 내용 구성

extension EventLiveActivityUsecaseImpleTests {

    @Test func usecase_whenTargetIsNotInSharedState_throwsEventNotFound() async throws {
        // given
        let (usecase, _, _) = self.makeUsecase()

        // when
        var caught: EventLiveActivityStartFailReason?
        do {
            try await usecase.startActivity(.todo(id: "missing"))
        } catch let error as EventLiveActivityStartFailReason {
            caught = error
        }

        // then
        #expect(caught == .eventNotFound)
    }

    @Test func usecase_startActivity_buildsContentFromSharedState() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", name: "meeting", eventDate: future, location: "3F")]
        )

        // when
        try await usecase.startActivity(
            .googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1")
        )

        // then
        let canonical = Date(timeIntervalSince1970: future.timeIntervalSince1970)
        let content = try #require(stub.didStartWith?.1)
        #expect(content.eventName == "meeting")
        #expect(content.placeName == "3F")
        #expect(content.eventDate == canonical)
        #expect(content.eventTimeText == self.expectedTimeText(for: canonical))
    }

    @Test func usecase_startActivity_resolvesTagColorFromSharedTags() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        let tag = CustomEventTag(uuid: "tag1", name: "work", colorHex: "#123456")
        store.put(
            [EventTagId: any EventTag].self, key: ShareDataKeys.tags.rawValue, [tag.tagId: tag]
        )
        self.putTodos(store, [
            self.makeTodo(id: "t1", eventDate: future) |> \.eventTagId .~ EventTagId.custom("tag1")
        ])

        // when
        try await usecase.startActivity(.todo(id: "t1"))

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#123456")
    }

    @Test func usecase_startActivity_holidayTarget_usesHolidayDefaultColor() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let scenario = self.holidayTimeZoneScenario()
        store.put(TimeZone.self, key: ShareDataKeys.timeZone.rawValue, scenario.timeZone)
        store.put(
            DefaultEventTagColorSetting.self, key: ShareDataKeys.defaultEventTagColor.rawValue,
            DefaultEventTagColorSetting(holiday: "#111111", default: "#222222")
        )
        store.put(
            [String: [Int: [Holiday]]].self, key: ShareDataKeys.holidays.rawValue,
            ["KR": [2026: [Holiday(uuid: "hz", dateString: scenario.dateString, name: "holiday")]]]
        )

        // when
        try await usecase.startActivity(.holiday(uuid: "hz", dateString: scenario.dateString))

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#111111")
    }

    /// 남은시간 링의 분모 시작점은 등록 시점이어야 한다 — 이벤트 시각을 넣으면 링이 처음부터 꽉 찬다.
    @Test func usecase_startActivity_setsStartDateToRegistrationTime() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])
        let before = Date()

        // when
        try await usecase.startActivity(.todo(id: "t1"))

        // then
        let startDate = try #require(stub.didStartWith?.1.startDate)
        #expect(startDate >= before)
        #expect(startDate <= Date())
    }

    @Test func usecase_startScheduleActivity_fillsScheduleTimeQueryFromOriginTime() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        let schedule = self.makeSchedule(id: "s1", eventDate: future)
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>().append(schedule)
        )

        // when
        try await usecase.startActivity(.schedule(id: "s1", turnKey: nil))

        // then
        #expect(stub.didStartWith?.1.scheduleTimeQuery == schedule.time.queryParams)
    }

    /// 원본 회차는 `schedule.time`을 그대로 실어야 초 미만 정밀도가 보존된다.
    @Test func usecase_startScheduleActivity_originOccurrence_fillsScheduleTimeQueryLosslessly() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60.4)
        let schedule = self.makeSchedule(id: "s1", eventDate: future)
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>().append(schedule)
        )

        // when
        try await usecase.startActivity(.schedule(id: "s1", turnKey: nil))

        // then
        let query = try #require(stub.didStartWith?.1.scheduleTimeQuery)
        #expect(EventTime(deepLink: query) == schedule.time)
    }

    @Test func usecase_startRepeatingScheduleActivity_fillsScheduleTimeQueryFromTurnKey() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let originTime = Date().addingTimeInterval(60)
        let turnTime = Date().addingTimeInterval(3600)
        let turnKey = EventTime.at(turnTime.timeIntervalSince1970).customKey
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>()
                .append(self.makeSchedule(id: "s1", eventDate: originTime))
        )

        // when
        try await usecase.startActivity(.schedule(id: "s1", turnKey: turnKey))

        // then
        let expectedQuery = try #require(EventTime(customKey: turnKey)).queryParams
        #expect(stub.didStartWith?.1.scheduleTimeQuery == expectedQuery)
    }

    @Test func usecase_startTodoActivity_leavesScheduleTimeQueryNil() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])

        // when
        try await usecase.startActivity(.todo(id: "t1"))

        // then
        #expect(stub.didStartWith?.1.scheduleTimeQuery == nil)
    }
}


// MARK: - 외부 캘린더 태그색 해석

extension EventLiveActivityUsecaseImpleTests {

    private func makeGoogleTag(id: String, colorHex: String) -> GoogleCalendar.Tag {
        return GoogleCalendar.Tag(id: id, name: "cal")
            |> \.backgroundColorHex .~ colorHex
    }

    @Test func usecase_startActivity_googleTarget_usesMatchingCalendarTagColor() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", eventDate: future)]
        )
        store.put(
            [String: [GoogleCalendar.Tag]].self, key: ShareDataKeys.googleCalendarTags.rawValue,
            ["acc": [
                self.makeGoogleTag(id: "other", colorHex: "#000000"),
                self.makeGoogleTag(id: "cal", colorHex: "#AAA111")
            ]]
        )

        // when
        try await usecase.startActivity(
            .googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1")
        )

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#AAA111")
    }

    @Test func usecase_startActivity_googleTarget_whenCalendarTagMissing_usesDefaultColor() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            DefaultEventTagColorSetting.self, key: ShareDataKeys.defaultEventTagColor.rawValue,
            DefaultEventTagColorSetting(holiday: "#111111", default: "#222222")
        )
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", eventDate: future)]
        )
        store.put(
            [String: [GoogleCalendar.Tag]].self, key: ShareDataKeys.googleCalendarTags.rawValue,
            ["other-account": [self.makeGoogleTag(id: "other-cal", colorHex: "#AAA111")]]
        )

        // when
        try await usecase.startActivity(
            .googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1")
        )

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#222222")
    }

    @Test func usecase_startActivity_googleTarget_whenAccountNotMatched_usesDefaultColor() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            DefaultEventTagColorSetting.self, key: ShareDataKeys.defaultEventTagColor.rawValue,
            DefaultEventTagColorSetting(holiday: "#111111", default: "#222222")
        )
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", eventDate: future)]
        )
        store.put(
            [String: [GoogleCalendar.Tag]].self, key: ShareDataKeys.googleCalendarTags.rawValue,
            ["other-account": [self.makeGoogleTag(id: "cal", colorHex: "#AAA111")]]
        )

        // when
        try await usecase.startActivity(
            .googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1")
        )

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#222222")
    }

    @Test func usecase_startActivity_googleTarget_whenEventColorIdOnlyInOtherAccountPalette_doesNotLeak() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            DefaultEventTagColorSetting.self, key: ShareDataKeys.defaultEventTagColor.rawValue,
            DefaultEventTagColorSetting(holiday: "#111111", default: "#222222")
        )
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", calendarId: "cal", accountId: "acc", colorId: "5", eventDate: future)]
        )
        store.put(
            [String: GoogleCalendar.Colors].self, key: ShareDataKeys.googleCalendarColors.rawValue,
            ["other-account": self.makeGooglePalette(ownerId: "other-account", events: ["5": "#leaked"])]
        )

        // when
        try await usecase.startActivity(
            .googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1")
        )

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#222222")
    }

    @Test func usecase_startActivity_googleTarget_whenEventHasColorId_usesEventPaletteColorOverCalendarColor() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", colorId: "5", eventDate: future)]
        )
        store.put(
            [String: [GoogleCalendar.Tag]].self, key: ShareDataKeys.googleCalendarTags.rawValue,
            ["acc": [self.makeGoogleTag(id: "cal", colorHex: "#calendarColor") |> \.ownerId .~ "acc"]]
        )
        store.put(
            [String: GoogleCalendar.Colors].self, key: ShareDataKeys.googleCalendarColors.rawValue,
            ["acc": self.makeGooglePalette(ownerId: "acc", events: ["5": "#eventColor"])]
        )

        // when
        try await usecase.startActivity(
            .googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1")
        )

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#eventColor")
    }

    @Test func usecase_startActivity_googleTarget_whenCalendarHasOnlyPaletteColorId_resolvesFromPalette() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: GoogleCalendar.Event].self, key: ShareDataKeys.googleCalendarEvents.rawValue,
            ["g1": self.makeGoogleEvent(id: "g1", eventDate: future)]
        )
        let tagWithPaletteOnly = GoogleCalendar.Tag(id: "cal", name: "cal")
            |> \.ownerId .~ "acc"
            |> \.colorId .~ "3"
        store.put(
            [String: [GoogleCalendar.Tag]].self, key: ShareDataKeys.googleCalendarTags.rawValue,
            ["acc": [tagWithPaletteOnly]]
        )
        store.put(
            [String: GoogleCalendar.Colors].self, key: ShareDataKeys.googleCalendarColors.rawValue,
            ["acc": self.makeGooglePalette(ownerId: "acc", calendars: ["3": "#paletteCalendarColor"])]
        )

        // when
        try await usecase.startActivity(
            .googleCalendar(accountId: "acc", calendarId: "cal", eventId: "g1")
        )

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#paletteCalendarColor")
    }

    private func makeGooglePalette(
        ownerId: String, calendars: [String: String] = [:], events: [String: String] = [:]
    ) -> GoogleCalendar.Colors {
        return GoogleCalendar.Colors(
            ownerId: ownerId,
            calendars: calendars.mapValues { .init(foregroundHex: "fg", backgroudHex: $0) },
            events: events.mapValues { .init(foregroundHex: "fg", backgroudHex: $0) }
        )
    }

    @Test func usecase_startActivity_appleTarget_usesMatchingCalendarTagColor() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            [String: AppleCalendar.Event].self, key: ShareDataKeys.appleCalendarEvents.rawValue,
            ["a1": self.makeAppleEvent(id: "a1", eventDate: future)]
        )
        store.put(
            [AppleCalendar.Tag].self, key: ShareDataKeys.appleCalendarTags.rawValue,
            [
                AppleCalendar.Tag(id: "other", name: "other", colorHex: "#000000"),
                AppleCalendar.Tag(id: "cal", name: "cal", colorHex: "#BBB222")
            ]
        )

        // when
        try await usecase.startActivity(.appleCalendar(calendarId: "cal", eventId: "a1"))

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#BBB222")
    }

    @Test func usecase_startActivity_appleTarget_whenCalendarTagMissing_usesDefaultColor() async throws {
        // given
        let (usecase, stub, store) = self.makeUsecase()
        let future = Date().addingTimeInterval(60)
        store.put(
            DefaultEventTagColorSetting.self, key: ShareDataKeys.defaultEventTagColor.rawValue,
            DefaultEventTagColorSetting(holiday: "#111111", default: "#222222")
        )
        store.put(
            [String: AppleCalendar.Event].self, key: ShareDataKeys.appleCalendarEvents.rawValue,
            ["a1": self.makeAppleEvent(id: "a1", eventDate: future)]
        )
        store.put(
            [AppleCalendar.Tag].self, key: ShareDataKeys.appleCalendarTags.rawValue,
            [AppleCalendar.Tag(id: "other", name: "other", colorHex: "#000000")]
        )

        // when
        try await usecase.startActivity(.appleCalendar(calendarId: "cal", eventId: "a1"))

        // then
        #expect(stub.didStartWith?.1.tagColorHex == "#222222")
    }
}


// MARK: - 잠금화면 부제

extension EventLiveActivityUsecaseImpleTests {

    private func makeDetail(
        _ eventId: String, place: String? = nil, memo: String? = nil
    ) -> EventDetailData {
        return EventDetailData(eventId)
            |> \.place .~ place.map { Place($0) }
            |> \.memo .~ memo
    }

    @Test func usecase_startTodoActivity_fillsPlaceNameFromEventDetail() async throws {
        // given
        let detailUsecase = SpyEventDetailDataUsecase()
        detailUsecase.stubDetail = self.makeDetail("t1", place: "회의실 A", memo: "준비물")
        let (usecase, stub, store) = self.makeUsecase(eventDetailUsecase: detailUsecase)
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])

        // when
        try await usecase.startActivity(.todo(id: "t1"))

        // then
        let content = try #require(stub.didStartWith?.1)
        #expect(detailUsecase.didLoadDetailIds == ["t1"])
        #expect(content.placeName == "회의실 A")
        #expect(content.memo == "준비물")
    }

    @Test func usecase_startTodoActivity_whenPlaceIsNil_fillsMemoOnly() async throws {
        // given
        let detailUsecase = SpyEventDetailDataUsecase()
        detailUsecase.stubDetail = self.makeDetail("t1", memo: "준비물")
        let (usecase, stub, store) = self.makeUsecase(eventDetailUsecase: detailUsecase)
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])

        // when
        try await usecase.startActivity(.todo(id: "t1"))

        // then
        let content = try #require(stub.didStartWith?.1)
        #expect(content.placeName == nil)
        #expect(content.memo == "준비물")
    }

    @Test func usecase_startScheduleActivity_fillsPlaceNameFromEventDetail() async throws {
        // given
        let detailUsecase = SpyEventDetailDataUsecase()
        detailUsecase.stubDetail = self.makeDetail("s1", place: "3층 라운지")
        let (usecase, stub, store) = self.makeUsecase(eventDetailUsecase: detailUsecase)
        let future = Date().addingTimeInterval(60)
        store.put(
            MemorizedEventsContainer<ScheduleEvent>.self, key: ShareDataKeys.schedules.rawValue,
            MemorizedEventsContainer<ScheduleEvent>().append(self.makeSchedule(id: "s1", eventDate: future))
        )

        // when
        try await usecase.startActivity(
            .schedule(id: "s1", turnKey: EventTime.at(future.timeIntervalSince1970).customKey)
        )

        // then
        let content = try #require(stub.didStartWith?.1)
        #expect(detailUsecase.didLoadDetailIds == ["s1"])
        #expect(content.placeName == "3층 라운지")
    }

    @Test func usecase_startHolidayActivity_notLoadEventDetail() async throws {
        // given
        let detailUsecase = SpyEventDetailDataUsecase()
        let (usecase, stub, store) = self.makeUsecase(eventDetailUsecase: detailUsecase)
        let scenario = self.holidayTimeZoneScenario()
        store.put(TimeZone.self, key: ShareDataKeys.timeZone.rawValue, scenario.timeZone)
        store.put(
            [String: [Int: [Holiday]]].self, key: ShareDataKeys.holidays.rawValue,
            ["KR": [2026: [Holiday(uuid: "hz", dateString: scenario.dateString, name: "holiday")]]]
        )

        // when
        try await usecase.startActivity(.holiday(uuid: "hz", dateString: scenario.dateString))

        // then
        #expect(detailUsecase.didLoadDetailIds.isEmpty)
        #expect(stub.didStartWith?.1.placeName == nil)
    }

    @Test func usecase_startActivity_whenEventDetailNeverResponds_startsWithoutSubtitle() async throws {
        // given
        let detailUsecase = SpyEventDetailDataUsecase()
        detailUsecase.stubNeverResponds = true
        let (usecase, stub, store) = self.makeUsecase(eventDetailUsecase: detailUsecase)
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", eventDate: future)])

        // when
        try await usecase.startActivity(.todo(id: "t1"))

        // then
        let content = try #require(stub.didStartWith?.1)
        #expect(content.placeName == nil)
        #expect(content.memo == nil)
    }

    @Test func usecase_whenUpdatedAfterRegistration_keepsSubtitle() async throws {
        // given
        let detailUsecase = SpyEventDetailDataUsecase()
        detailUsecase.stubDetail = self.makeDetail("t1", place: "회의실 A", memo: "준비물")
        let (usecase, stub, store) = self.makeUsecase(eventDetailUsecase: detailUsecase)
        let future = Date().addingTimeInterval(60)
        self.putTodos(store, [self.makeTodo(id: "t1", name: "old", eventDate: future)])
        try await usecase.startActivity(.todo(id: "t1"))

        // when
        self.putTodos(store, [self.makeTodo(id: "t1", name: "new", eventDate: future)])
        try await self.waitForEffects()

        // then
        let content = try #require(stub.didUpdateWith)
        #expect(content.eventName == "new")
        #expect(content.placeName == "회의실 A")
        #expect(content.memo == "준비물")
    }
}


private final class SpyEventDetailDataUsecase: StubEventDetailDataUsecase, @unchecked Sendable {

    var didLoadDetailIds: [String] = []
    var stubNeverResponds: Bool = false

    override func loadDetail(_ id: String) -> AnyPublisher<EventDetailData, any Error> {
        self.didLoadDetailIds.append(id)
        guard self.stubNeverResponds == false
        else { return Empty(completeImmediately: false).eraseToAnyPublisher() }
        return super.loadDetail(id)
    }
}
