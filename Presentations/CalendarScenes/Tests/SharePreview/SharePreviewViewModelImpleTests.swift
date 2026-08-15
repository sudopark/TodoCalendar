//
//  SharePreviewViewModelImpleTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Scenes
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import CalendarScenes


final class SharePreviewViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private let eventTagUsecase = StubEventTagUsecase()
    private let uiSettingUsecase = StubUISettingUsecase()
    private let eventShareSettingUsecase = StubEventShareSettingUsecase()
    private let router = SpySharePreviewRouter()
    private let taggedId = EventTagId.custom("tag-a")

    private func september10thRange() -> Range<TimeInterval> {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ TimeZone(abbreviation: "KST")!
        let component = DateComponents(year: 2023, month: 9, day: 10)
        let start = calendar.date(from: component)!.timeIntervalSince1970
        return start..<(start + 3600 * 24)
    }

    private func deletedTagTodo() -> TodoEvent {
        let range = self.september10thRange()
        return TodoEvent(uuid: "todo:deleted-tag", name: "deleted-tag-todo")
            |> \.time .~ .at(range.lowerBound + 3600 * 13)
            |> \.eventTagId .~ .custom("not_exists")
    }

    private func makeViewModel(
        offTagIds: [EventTagId] = [],
        foremostEventId: ForemostEventId? = nil,
        includeTagName: Bool = false,
        todos: [TodoEvent]? = nil,
        currentTodos: [TodoEvent]? = nil,
        schedules: [ScheduleEvent]? = nil,
        googleEvents: [GoogleCalendar.Event]? = nil,
        googleTags: [GoogleCalendar.Tag]? = nil,
        appleEvents: [AppleCalendar.Event]? = nil,
        appleTags: [AppleCalendar.Tag]? = nil
    ) throws -> SharePreviewViewModelImple {
        let range = self.september10thRange()

        let todoUsecase = StubTodoEventUsecase()
        todoUsecase.stubTodoEventsInRange = todos ?? [
            TodoEvent(uuid: "todo:0", name: "range-todo")
                |> \.time .~ .at(range.lowerBound + 3600 * 13)
                |> \.eventTagId .~ self.taggedId
        ]
        todoUsecase.stubCurrentTodoEvents = currentTodos ?? [
            TodoEvent(uuid: "c-t:0", name: "current-todo")
                |> \.eventTagId .~ .default
                |> \.creatTimeStamp .~ 100
        ]

        let scheduleUsecase = StubScheduleEventUsecase()
        scheduleUsecase.stubScheduleEventsInRange = schedules ?? [
            ScheduleEvent(uuid: "sc:0", name: "range-schedule", time: .at(range.lowerBound + 3600 * 9))
                |> \.eventTagId .~ .default
        ]

        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()

        var setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "", default: "")
        )
        setting.calendar.is24hourForm = true
        self.uiSettingUsecase.stubAppearanceSetting = setting
        _ = self.uiSettingUsecase.loadSavedAppearanceSetting()

        self.eventTagUsecase.addEventTagOffIds(offTagIds)

        let foremostUsecase = StubForemostEventUsecase(foremostId: foremostEventId)
        foremostUsecase.refresh()

        self.eventShareSettingUsecase.stubSetting = EventShareSettings()
            |> \.includeTagName .~ includeTagName

        let googleCalendarUsecase = StubGoogleCalendarUsecase()
        googleCalendarUsecase.stubEvents = googleEvents ?? []
        googleCalendarUsecase.stubCalendarTags = googleTags ?? []
        googleCalendarUsecase.refreshGoogleCalendarEventTags()

        let appleCalendarUsecase = StubAppleCalendarUsecase()
        appleCalendarUsecase.stubEvents = appleEvents ?? []
        appleCalendarUsecase.stubCalendarTags = appleTags ?? []
        appleCalendarUsecase.refreshCalendarTags()

        let eventListUsecase = CalendarEventListhUsecaseImple(
            todoUsecase: todoUsecase,
            scheduleUsecase: scheduleUsecase,
            googleCalendarUsecase: googleCalendarUsecase,
            appleCalendarUsecase: appleCalendarUsecase,
            foremostEventUsecase: foremostUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: self.eventTagUsecase,
            uiSettingUsecase: self.uiSettingUsecase
        )

        let viewModel = SharePreviewViewModelImple(
            range: range,
            eventListUsecase: eventListUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            uiSettingUsecase: self.uiSettingUsecase,
            eventTagUsecase: self.eventTagUsecase,
            eventShareSettingUsecase: self.eventShareSettingUsecase,
            googleCalendarUsecase: googleCalendarUsecase,
            appleCalendarUsecase: appleCalendarUsecase
        )
        viewModel.router = self.router
        return viewModel
    }
}


// MARK: - lineModels 제공

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_whenPrepare_providesLineModelsForRange() async throws {
        // given
        let expect = expectConfirm("범위 이벤트가 행 모델로 방출된다")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let ids = lines?.map { $0.eventId }.sorted()
        #expect(ids == ["c-t:0", "sc:0-1", "todo:0"])
    }

    @Test func viewModel_lineModels_includeEventsOfOffTags() async throws {
        // given
        let expect = expectConfirm("캘린더에서 숨긴 태그 이벤트도 행에 포함된다")
        let viewModel = try self.makeViewModel(offTagIds: [self.taggedId])

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let containsOffTagEvent = lines?.contains(where: { $0.eventId == "todo:0" }) ?? false
        #expect(containsOffTagEvent)
    }

    @Test func viewModel_lineModels_includeForemostEvent() async throws {
        // given
        let expect = expectConfirm("강조 이벤트도 행에 포함된다")
        let viewModel = try self.makeViewModel(foremostEventId: .init("todo:0", true))

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let containsForemostEvent = lines?.contains(where: { $0.eventId == "todo:0" }) ?? false
        #expect(containsForemostEvent)
    }

    @Test func viewModel_lineModels_sortedByEventListOrder() async throws {
        // given
        let expect = expectConfirm("시간 없는 할일이 먼저, 그다음 시간 있는 이벤트")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        #expect(lines?.map { $0.eventId } == ["c-t:0", "sc:0-1", "todo:0"])
    }

    @Test func viewModel_lineModels_resolveTagName() async throws {
        // given
        let expect = expectConfirm("tagName이 태그 이름으로 채워진다")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let taggedLine = lines?.first(where: { $0.eventId == "todo:0" })
        #expect(taggedLine?.tagName == "some")
    }

    @Test func viewModel_lineModels_whenEventHasDeletedTag_resolveAsDefaultTag() async throws {
        // given
        let expect = expectConfirm("삭제된 태그를 단 이벤트는 기본 태그로 해석된다")
        let viewModel = try self.makeViewModel(todos: [self.deletedTagTodo()])

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let deletedTagLine = lines?.first(where: { $0.eventId == "todo:deleted-tag" })
        #expect(deletedTagLine?.tagId == .default)
        #expect(deletedTagLine?.tagName == DefaultEventTag.default("").name)
    }
}


// MARK: - 범위 겹침 재판정

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_lineModels_excludeEventsNotOverlappingRange() async throws {
        // given
        let expect = expectConfirm("범위와 안 겹치는 반복 회차는 행 목록에서 빠진다")
        let range = self.september10thRange()
        let repeatingSchedule = ScheduleEvent(
            uuid: "sc:multi", name: "multi-turn-schedule", time: .at(range.lowerBound - 3600 * 24)
        )
            |> \.eventTagId .~ .default
            |> \.repeating .~ (
                EventRepeating(
                    repeatingStartTime: range.lowerBound - 3600 * 24,
                    repeatOption: EventRepeatingOptions.EveryDay()
                )
                |> \.repeatingEndOption .~ .count(3)
            )
            |> \.nextRepeatingTimes .~ [
                .init(time: .at(range.lowerBound + 3600 * 10), turn: 2),
                .init(time: .at(range.lowerBound + 3600 * 24 + 3600 * 10), turn: 3)
            ]
        let viewModel = try self.makeViewModel(schedules: [repeatingSchedule])

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let ids = Set(lines?.map { $0.eventId } ?? [])
        #expect(ids.contains("sc:multi-2"))
        #expect(ids.contains("sc:multi-1") == false)
        #expect(ids.contains("sc:multi-3") == false)
    }

    @Test func viewModel_lineModels_keepCurrentTodosWithoutEventTime() async throws {
        // given
        let expect = expectConfirm("시간 없는 현재 할일은 범위 필터에 걸리지 않는다")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let containsCurrentTodo = lines?.contains(where: { $0.eventId == "c-t:0" }) ?? false
        #expect(containsCurrentTodo)
    }
}


// MARK: - isTodo 판별

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_lineModels_markTodoEventsAsTodo() async throws {
        // given
        let expect = expectConfirm("todo 행은 isTodo, schedule 행은 아니다")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let todoLine = lines?.first(where: { $0.eventId == "todo:0" })
        let scheduleLine = lines?.first(where: { $0.eventId == "sc:0-1" })
        #expect(todoLine?.isTodo == true)
        #expect(scheduleLine?.isTodo == false)
    }

    @Test func viewModel_lineModels_markCurrentTodoAsTodo() async throws {
        // given
        let expect = expectConfirm("시간 없는 현재 할일도 isTodo")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let currentTodoLine = lines?.first(where: { $0.eventId == "c-t:0" })
        #expect(currentTodoLine?.isTodo == true)
    }
}


// MARK: - dateHeaderText

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_dateHeaderText_isProvided() async throws {
        // given
        let expect = expectConfirm("날짜 헤더가 방출된다")
        let viewModel = try self.makeViewModel()

        // when
        let headerText = try await self.firstOutput(expect, for: viewModel.dateHeaderText) {
            viewModel.prepare()
        }

        // then
        #expect(headerText?.isEmpty == false)
    }
}


// MARK: - timeText 조립

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_lineModel_timeText_whenTodoHasNoTime_isNil() async throws {
        // given
        let expect = expectConfirm("시간 없는 현재 할일은 timeText가 nil")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let currentTodoLine = lines?.first(where: { $0.eventId == "c-t:0" })
        #expect(currentTodoLine?.timeText == nil)
    }

    @Test func viewModel_lineModel_timeText_whenEventAtSingleTime_isThatTime() async throws {
        // given
        let expect = expectConfirm("단일 시각 이벤트는 시:분 문자열")
        let viewModel = try self.makeViewModel()

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let scheduleLine = lines?.first(where: { $0.eventId == "sc:0-1" })
        #expect(scheduleLine?.timeText == "9:00")
    }

    @Test func viewModel_lineModel_timeText_whenEventStartsAndEndsInDay_joinsWithTilde() async throws {
        // given
        let expect = expectConfirm("시작·끝 모두 그 날 안이면 물결로 연결")
        let range = self.september10thRange()
        let schedules = [
            ScheduleEvent(
                uuid: "sc:period", name: "period-schedule",
                time: .period(range.lowerBound + 3600 * 13..<range.lowerBound + 3600 * 14.5)
            )
                |> \.eventTagId .~ .default
        ]
        let viewModel = try self.makeViewModel(schedules: schedules)

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let line = lines?.first(where: { $0.name == "period-schedule" })
        #expect(line?.timeText == "13:00~14:30")
    }

    @Test func viewModel_lineModel_timeText_whenEventStartsInDayAndEndsLater_hasTrailingTilde() async throws {
        // given
        let expect = expectConfirm("시작만 그 날 안이면 물결이 뒤에")
        let range = self.september10thRange()
        let schedules = [
            ScheduleEvent(
                uuid: "sc:trailing", name: "trailing-schedule",
                time: .period(range.lowerBound + 3600 * 22..<range.upperBound + 3600 * 3)
            )
                |> \.eventTagId .~ .default
        ]
        let viewModel = try self.makeViewModel(schedules: schedules)

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let line = lines?.first(where: { $0.name == "trailing-schedule" })
        #expect(line?.timeText == "22:00~")
    }

    @Test func viewModel_lineModel_timeText_whenEventStartedBeforeAndEndsInDay_hasLeadingTilde() async throws {
        // given
        let expect = expectConfirm("끝만 그 날 안이면 물결이 앞에")
        let range = self.september10thRange()
        let schedules = [
            ScheduleEvent(
                uuid: "sc:leading", name: "leading-schedule",
                time: .period(range.lowerBound - 3600 * 3..<range.lowerBound + 3600 * 10)
            )
                |> \.eventTagId .~ .default
        ]
        let viewModel = try self.makeViewModel(schedules: schedules)

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let line = lines?.first(where: { $0.name == "leading-schedule" })
        #expect(line?.timeText == "~10:00")
    }

    @Test func viewModel_lineModel_timeText_whenEventCoversWholeDay_isAllDayText() async throws {
        // given
        let expect = expectConfirm("그 날을 통째로 덮으면 종일 문구")
        let range = self.september10thRange()
        let schedules = [
            ScheduleEvent(
                uuid: "sc:allday", name: "allday-schedule",
                time: .period(range.lowerBound - 3600 * 5..<range.upperBound + 3600 * 5)
            )
                |> \.eventTagId .~ .default
        ]
        let viewModel = try self.makeViewModel(schedules: schedules)

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let line = lines?.first(where: { $0.name == "allday-schedule" })
        #expect(line?.timeText == R.String.calendarEventTimeAllday)
    }
}


// MARK: - 태그 셀 목록

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_tagCellViewModels_listOnlyTagsInRange() async throws {
        // given
        let expect = expectConfirm("범위 이벤트가 가진 태그만 셀로 나온다")
        let unusedTagId = EventTagId.custom("unused-tag")
        let viewModel = try self.makeViewModel(offTagIds: [unusedTagId])

        // when
        let cells = try await self.firstOutput(expect, for: viewModel.tagCellViewModels) {
            viewModel.prepare()
        }

        // then
        let tagIds = Set(cells?.map { $0.tagId } ?? [])
        #expect(tagIds == [self.taggedId, .default])
    }

    @Test func viewModel_tagCellViewModels_whenEventHasDeletedTag_mergedIntoDefaultTagCell() async throws {
        // given
        let expect = expectConfirm("삭제된 태그 이벤트는 기본 태그 셀로 합쳐진다")
        let viewModel = try self.makeViewModel(todos: [self.deletedTagTodo()])

        // when
        let cells = try await self.firstOutput(expect, for: viewModel.tagCellViewModels) {
            viewModel.prepare()
        }

        // then
        let tagIds = Set(cells?.map { $0.tagId } ?? [])
        #expect(tagIds == [.default])
        #expect(cells?.first?.name == DefaultEventTag.default("").name)
    }

    @Test func viewModel_tagCellViewModels_offTagsOnCalendar_startAsOff() async throws {
        // given
        let expect = expectConfirm("캘린더에서 숨긴 태그는 isOn == false로 시작")
        let viewModel = try self.makeViewModel(offTagIds: [self.taggedId])

        // when
        let cells = try await self.firstOutput(expect, for: viewModel.tagCellViewModels) {
            viewModel.prepare()
        }

        // then
        let taggedCell = cells?.first(where: { $0.tagId == self.taggedId })
        let defaultCell = cells?.first(where: { $0.tagId == .default })
        #expect(taggedCell?.isOn == false)
        #expect(defaultCell?.isOn == true)
    }
}


// MARK: - 외부 캘린더 태그 이름 해석

extension SharePreviewViewModelImpleTests {

    private func makeExternalCalendarFixture() -> (
        googleEvent: GoogleCalendar.Event, googleTag: GoogleCalendar.Tag,
        appleEvent: AppleCalendar.Event, appleTag: AppleCalendar.Tag
    ) {
        let range = self.september10thRange()
        let googleEvent = GoogleCalendar.Event(
            "g-event-1", "google-cal-1",
            accountId: "user@gmail.com", name: "google-event", colorId: nil,
            time: .at(range.lowerBound + 3600 * 8)
        )
        let googleTag = GoogleCalendar.Tag(id: "google-cal-1", name: "Google Team")
        let appleEvent = AppleCalendar.Event(
            eventId: "a-event-1", originalEventId: "a-event-1", calendarId: "apple-cal-1",
            name: "apple-event", eventTime: .at(range.lowerBound + 3600 * 9)
        )
        let appleTag = AppleCalendar.Tag(id: "apple-cal-1", name: "Apple Family", colorHex: nil)
        return (googleEvent, googleTag, appleEvent, appleTag)
    }

    @Test func viewModel_tagCellViewModels_resolveExternalCalendarTagNames() async throws {
        // given
        let expect = expectConfirm("구글·애플 캘린더 태그 셀에 이름이 채워진다")
        let fixture = self.makeExternalCalendarFixture()
        let viewModel = try self.makeViewModel(
            googleEvents: [fixture.googleEvent], googleTags: [fixture.googleTag],
            appleEvents: [fixture.appleEvent], appleTags: [fixture.appleTag]
        )

        // when
        let cells = try await self.firstOutput(expect, for: viewModel.tagCellViewModels) {
            viewModel.prepare()
        }

        // then
        let googleCell = cells?.first(where: { $0.tagId == fixture.googleTag.tagId })
        let appleCell = cells?.first(where: { $0.tagId == fixture.appleTag.tagId })
        #expect(googleCell?.name == "Google Team")
        #expect(appleCell?.name == "Apple Family")
    }

    @Test func viewModel_lineModels_resolveExternalCalendarTagName() async throws {
        // given
        let expect = expectConfirm("구글·애플 이벤트 행의 tagName이 채워진다")
        let fixture = self.makeExternalCalendarFixture()
        let viewModel = try self.makeViewModel(
            googleEvents: [fixture.googleEvent], googleTags: [fixture.googleTag],
            appleEvents: [fixture.appleEvent], appleTags: [fixture.appleTag]
        )

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels) {
            viewModel.prepare()
        }

        // then
        let googleLine = lines?.first(where: { $0.name == "google-event" })
        let appleLine = lines?.first(where: { $0.name == "apple-event" })
        #expect(googleLine?.tagName == "Google Team")
        #expect(appleLine?.tagName == "Apple Family")
    }
}


// MARK: - 태그·개별 제외 필터

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_whenToggleTag_off_excludesItsLines() async throws {
        // given
        let expect = expectConfirm("태그를 끄면 그 태그 행이 isExcluded")
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels.dropFirst()) {
            viewModel.toggleTag(self.taggedId)
        }

        // then
        let taggedLine = lines?.first(where: { $0.eventId == "todo:0" })
        #expect(taggedLine?.isExcluded == true)
        #expect(lines?.contains(where: { $0.eventId == "todo:0" }) == true)
    }

    @Test func viewModel_whenToggleTag_onCalendarOffTag_includesItsLinesAgain() async throws {
        // given
        let viewModel = try self.makeViewModel(offTagIds: [self.taggedId])
        viewModel.prepare()
        let initialLines = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }
        let initiallyExcluded = initialLines?.first(where: { $0.eventId == "todo:0" })?.isExcluded

        // when
        let lines = try await self.firstOutput(expectConfirm("태그 재활성 반영"), for: viewModel.lineModels.dropFirst()) {
            viewModel.toggleTag(self.taggedId)
        }

        // then
        #expect(initiallyExcluded == true)
        let taggedLine = lines?.first(where: { $0.eventId == "todo:0" })
        #expect(taggedLine?.isExcluded == false)
    }

    @Test func viewModel_whenDeselectAllTags_allLinesExcluded() async throws {
        // given
        let expect = expectConfirm("전체 해제하면 모든 행이 제외된다")
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels.dropFirst()) {
            viewModel.deselectAllTags()
        }

        // then
        #expect(lines?.allSatisfy { $0.isExcluded } == true)
    }

    @Test func viewModel_whenSelectAllTags_noLineExcluded() async throws {
        // given
        let viewModel = try self.makeViewModel(offTagIds: [self.taggedId])
        viewModel.prepare()
        let initialLines = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }
        let initiallyExcluded = initialLines?.contains(where: { $0.isExcluded })

        // when
        let lines = try await self.firstOutput(expectConfirm("전체 선택 반영"), for: viewModel.lineModels.dropFirst()) {
            viewModel.selectAllTags()
        }

        // then
        #expect(initiallyExcluded == true)
        #expect(lines?.contains(where: { $0.isExcluded }) == false)
    }

    @Test func viewModel_whenToggleLine_excludesOnlyThatLine() async throws {
        // given
        let expect = expectConfirm("개별 체크는 그 행만 제외한다")
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels.dropFirst()) {
            viewModel.toggleLine("todo:0")
        }

        // then
        let excludedIds = lines?.filter { $0.isExcluded }.map { $0.eventId }
        #expect(excludedIds == ["todo:0"])
    }

    @Test func viewModel_whenTagIsOff_marksLineAsExcludedByTag() async throws {
        // given
        let expect = expectConfirm("태그를 끄면 그 태그 행이 isExcludedByTag")
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels.dropFirst()) {
            viewModel.toggleTag(self.taggedId)
        }

        // then
        let taggedLine = lines?.first(where: { $0.eventId == "todo:0" })
        #expect(taggedLine?.isExcludedByTag == true)
        #expect(taggedLine?.isExcluded == true)
    }

    @Test func viewModel_whenOnlyLineIsToggled_isNotExcludedByTag() async throws {
        // given
        let expect = expectConfirm("개별 체크만 해제한 행은 isExcludedByTag가 false")
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }

        // when
        let lines = try await self.firstOutput(expect, for: viewModel.lineModels.dropFirst()) {
            viewModel.toggleLine("todo:0")
        }

        // then
        let taggedLine = lines?.first(where: { $0.eventId == "todo:0" })
        #expect(taggedLine?.isExcluded == true)
        #expect(taggedLine?.isExcludedByTag == false)
    }

    @Test func viewModel_whenTagIsTurnedOnAgain_clearsExcludedByTag() async throws {
        // given
        let viewModel = try self.makeViewModel(offTagIds: [self.taggedId])
        viewModel.prepare()
        let initialLines = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }
        let initiallyExcludedByTag = initialLines?.first(where: { $0.eventId == "todo:0" })?.isExcludedByTag

        // when
        let lines = try await self.firstOutput(expectConfirm("태그 재활성 반영"), for: viewModel.lineModels.dropFirst()) {
            viewModel.toggleTag(self.taggedId)
        }

        // then
        #expect(initiallyExcludedByTag == true)
        let taggedLine = lines?.first(where: { $0.eventId == "todo:0" })
        #expect(taggedLine?.isExcludedByTag == false)
    }
}


// MARK: - 공유 가능 여부

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_isShareEnabled_falseWhenAllLinesExcluded() async throws {
        // given
        let expect = expectConfirm("남는 행이 0이면 공유 불가")
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }

        // when
        let isEnabled = try await self.firstOutput(expect, for: viewModel.isShareEnabled.dropFirst()) {
            viewModel.deselectAllTags()
        }

        // then
        #expect(isEnabled == false)
    }
}


// MARK: - 공유 실행

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_whenShare_routesWithAssembledText() async throws {
        // given
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }
        _ = try await self.firstOutput(expectConfirm("태그 제외 반영"), for: viewModel.lineModels.dropFirst()) {
            viewModel.toggleTag(self.taggedId)
        }

        // when
        viewModel.share()

        // then
        let text = self.router.didShareWithText
        #expect(text?.contains("range-schedule") == true)
        #expect(text?.contains("current-todo") == true)
        #expect(text?.contains("range-todo") == false)
    }

    @Test func viewModel_whenShare_andAllLinesExcluded_doesNotRoute() async throws {
        // given
        let viewModel = try self.makeViewModel()
        viewModel.prepare()
        _ = try await self.firstOutput(expectConfirm("초기 로드"), for: viewModel.lineModels) { }
        _ = try await self.firstOutput(expectConfirm("전체 제외 반영"), for: viewModel.lineModels.dropFirst()) {
            viewModel.deselectAllTags()
        }

        // when
        viewModel.share()

        // then
        #expect(self.router.didShareWithText == nil)
    }
}


// MARK: - 태그명 포함 설정

extension SharePreviewViewModelImpleTests {

    @Test func viewModel_whenToggleIncludeTagName_savesSetting() async throws {
        // given
        let viewModel = try self.makeViewModel()

        // when
        viewModel.toggleIncludeTagName(true)

        // then
        #expect(self.eventShareSettingUsecase.didChangeEventShareParams?.includeTagName == true)
    }

    @Test func viewModel_includeTagName_restoresSavedValue() async throws {
        // given
        let expect = expectConfirm("저장된 값으로 시작한다")
        expect.count = 2
        let viewModel = try self.makeViewModel(includeTagName: true)

        // when
        let values = try await self.outputs(expect, for: viewModel.includeTagName) {
            viewModel.prepare()
        }

        // then
        #expect(values.last == true)
    }
}


// MARK: - doubles

private final class SpySharePreviewRouter: BaseSpyRouter, SharePreviewRouting, @unchecked Sendable {

    var didShareWithText: String?
    func showShareSheet(text: String) {
        self.didShareWithText = text
    }
}
