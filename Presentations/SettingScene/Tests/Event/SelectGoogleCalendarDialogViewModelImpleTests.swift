//
//  SelectGoogleCalendarDialogViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit

@testable import SettingScene
import EventDomainInterface
import EventDomainTesting
import ExternalCalendarDomainInterface
import ExternalCalendarDomainTesting
import TestDoubles


final class SelectGoogleCalendarDialogViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private let stubGoogleCalendarUsecase = StubGoogleCalendarUsecase()
    private let stubEventTagUsecase = StubEventTagUsecase()
    private let spyRouter = SpyRouter()

    private var aliceTags: [GoogleCalendar.Tag] {
        return ["a:0", "a:1", "a:2"].map {
            GoogleCalendar.Tag(id: $0, name: "name:\($0)") |> \.ownerId .~ "alice@gmail.com"
        }
    }

    private var bobTag: GoogleCalendar.Tag {
        return GoogleCalendar.Tag(id: "b:0", name: "name:b:0") |> \.ownerId .~ "bob@gmail.com"
    }

    private func makeViewModel(
        initialOffIds: [EventTagId] = []
    ) -> SelectGoogleCalendarDialogViewModelImple {
        let tags = self.aliceTags
        self.stubGoogleCalendarUsecase.stubCalendarTags = [tags[0], self.bobTag, tags[1], tags[2]]
        self.stubGoogleCalendarUsecase.refreshGoogleCalendarEventTags()
        self.stubEventTagUsecase.addEventTagOffIds(initialOffIds)

        let viewModel = SelectGoogleCalendarDialogViewModelImple(
            accountId: "alice@gmail.com",
            googleCalendarUsecase: self.stubGoogleCalendarUsecase,
            eventTagUsecase: self.stubEventTagUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}


// MARK: - 캘린더 목록 제공

extension SelectGoogleCalendarDialogViewModelImpleTests {

    @Test func viewModel_provideCalendarsOfAccountOnly() async throws {
        // given
        let expect = expectConfirm("그 계정 캘린더만 받은 순서대로")
        let viewModel = self.makeViewModel()

        // when
        let calendars = try await self.firstOutput(expect, for: viewModel.calendars)

        // then
        #expect(calendars?.map { $0.name } == ["name:a:0", "name:a:1", "name:a:2"])
        #expect(calendars?.map { $0.accountEmail } == [nil, nil, nil])
    }

    @Test func viewModel_provideIsOnFromOffIds() async throws {
        // given
        let expect = expectConfirm("offIds 에 든 캘린더는 꺼짐")
        let viewModel = self.makeViewModel(initialOffIds: [self.aliceTags[1].tagId])

        // when
        let calendars = try await self.firstOutput(expect, for: viewModel.calendars)

        // then
        #expect(calendars?.map { $0.isOn } == [true, false, true])
    }

    @Test func viewModel_whenOffIdsChanged_updateIsOn() async throws {
        // given
        let expect = expectConfirm("offIds 가 바뀌면 켜짐을 다시 방출")
        expect.count = 2
        let viewModel = self.makeViewModel()

        // when
        let calendarLists = try await self.outputs(expect, for: viewModel.calendars) {
            self.stubEventTagUsecase.toggleEventTagIsOnCalendar(self.aliceTags[2].tagId)
        }

        // then
        #expect(calendarLists.map { $0.map { $0.isOn } } == [
            [true, true, true],
            [true, true, false]
        ])
    }
}


// MARK: - 켜고 끄기·닫기

extension SelectGoogleCalendarDialogViewModelImpleTests {

    @Test func viewModel_whenToggle_toggleEventTagIsOnCalendar() async throws {
        // given
        let expect = expectConfirm("토글한 캘린더가 offIds 에 들어감")
        expect.count = 2
        let viewModel = self.makeViewModel()

        // when
        let offIdSets = try await self.outputs(expect, for: self.stubEventTagUsecase.offEventTagIdsOnCalendar()) {
            viewModel.toggleCalendar(self.aliceTags[0].tagId)
        }

        // then
        #expect(offIdSets == [[], [self.aliceTags[0].tagId]])
    }

    @Test func viewModel_close_closeScene() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.close()

        // then
        #expect(self.spyRouter.didClosed == true)
    }
}


private final class SpyRouter: BaseSpyRouter, SelectGoogleCalendarDialogRouting, @unchecked Sendable { }
