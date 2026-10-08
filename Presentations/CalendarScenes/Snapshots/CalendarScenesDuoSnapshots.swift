//
//  CalendarScenesDuoSnapshots.swift
//  CalendarScenes
//
//  Created by sudo.park on 9/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Prelude
import Optics
import Domain
import CommonPresentation
import SnapshotTestHelpKit

@testable import CalendarScenes
import CalendarPresentation


final class CalendarScenesDuoSnapshots: XCTestCase {

    // MARK: - Month/MonthView (rowHeight: medium)

    @MainActor
    func test_duoCover_month_mediumRowHeight() {
        captureSnapshotPair(named: "duoCover_month_mediumRowHeight", layout: .duoCover) { theme in
            self.makeMonthMediumRowHeightView(theme)
        }
    }

    @MainActor
    func test_duoInner_month_mediumRowHeight() {
        captureSnapshotPair(named: "duoInner_month_mediumRowHeight", layout: .duoInner) { theme in
            self.makeMonthMediumRowHeightView(theme)
        }
    }

    // MARK: - SharePreview (이미지 형식, 하루 목록)

    @MainActor
    func test_duoCover_sharePreview_imageFormat_dayList() {
        captureSnapshotPair(named: "duoCover_sharePreview_imageFormat_dayList", layout: .duoCover) { theme in
            self.makeSharePreviewImageDayListView(theme)
        }
    }

    @MainActor
    func test_duoInner_sharePreview_imageFormat_dayList() {
        captureSnapshotPair(named: "duoInner_sharePreview_imageFormat_dayList", layout: .duoInner) { theme in
            self.makeSharePreviewImageDayListView(theme)
        }
    }
}


// MARK: - 메인 캘린더 단 수 (커버 1단 · 내부 2단)

extension CalendarScenesDuoSnapshots {

    @MainActor
    func test_duoInner_calendarTwoColumns() {
        captureSnapshotPair(named: "duoInner_calendarTwoColumns", layout: .duoInner) { theme in
            self.makeTwoColumnsView(theme)
        }
    }

    @MainActor
    func test_duoCover_calendarSingleColumn() {
        captureSnapshotPair(named: "duoCover_calendarSingleColumn", layout: .duoCover) { theme in
            self.makeSingleColumnView(theme)
        }
    }
}


// MARK: - view builders

private extension CalendarScenesDuoSnapshots {

    @MainActor
    func makeMonthMediumRowHeightView(_ theme: SnapshotTheme) -> some View {
        let appearance = self.makeAppearance(theme, customTags: [])
        appearance.rowHeightOnCalendar = .medium

        let viewModel = DummyMonthViewModel()
        let state = MonthViewState()
        state.bind(viewModel, appearance)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        return MonthView()
            .environment(state)
            .environment(MonthViewEventHandler())
            .environment(appearance)
            .onAppear {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            }
    }

    @MainActor
    func makeSharePreviewImageDayListView(_ theme: SnapshotTheme) -> some View {
        let appearance = self.makeAppearance(theme, customTags: [
            CustomEventTag(uuid: "work", name: "업무", colorHex: "#4a90d9"),
            CustomEventTag(uuid: "personal", name: "개인", colorHex: "#50c878")
        ])
        let viewModel = FakeSharePreviewViewModel(
            isTagFilterExpanded: false,
            tagCellViewModels: [
                .init(tagId: .custom("work"), name: "업무", isOn: true),
                .init(tagId: .custom("personal"), name: "개인", isOn: true)
            ],
            lineModels: [],
            dateHeaderText: "08/15/2026 (Sat)",
            includeTagName: false,
            isShareEnabled: true,
            format: .image,
            imageContentModel: self.dayListContent(),
            isIncludeTagNameOptionVisible: false
        )
        let state = SharePreviewViewState()
        state.bind(viewModel)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        return SharePreviewView()
            .environment(state)
            .environment(SharePreviewViewEventHandler())
            .environment(appearance)
    }

    @MainActor
    func makeTwoColumnsView(_ theme: SnapshotTheme) -> some View {
        let appearance = self.makeAppearance(theme, customTags: [])
        appearance.rowHeightOnCalendar = .medium
        let monthsViewModel = DummyContinuousMonthsViewModel()
        let eventListViewModel = self.makeDayEventListViewModel()
        let nextDayViewModel = DummyNextDayEventListViewModel(
            dayModel: SelectedDayModel(dateText: "Sep 14, 2023 (Thu)", lunarDateText: ""),
            cellViewModels: [
                ScheduleEventCellViewModel("next-meeting", name: "next day meeting")
                    |> \.periodText .~ .singleText(.init(text: "10:00", pmOram: "AM"))
            ]
        )
        let viewModel = CalendarTwoColumnsViewModelImple(
            continuousMonthsInteractor: monthsViewModel,
            eventListInteractor: eventListViewModel,
            nextDayInteractor: nextDayViewModel
        )
        let pendingDoneState = PendingCompleteTodoState()
        let eventListView = DayEventListContainerView(
            viewAppearance: appearance,
            eventHandler: DayEventListViewEventHandler(),
            pendingDoneState: pendingDoneState
        )
        .eventHandler(\.stateBinding, { $0.bind(eventListViewModel, appearance) })
        let nextDayView = NextDayEventListContainerView(
            viewAppearance: appearance,
            eventHandler: NextDayEventListViewEventHandler(),
            pendingDoneState: pendingDoneState
        )
        .eventHandler(\.stateBinding, { $0.bind(nextDayViewModel, appearance) })
        let viewController = CalendarTwoColumnsViewController(
            viewModel: viewModel,
            monthsViewController: ContinuousMonthsViewController(viewModel: monthsViewModel, viewAppearance: appearance),
            listView: CalendarTwoColumnsListContainerView(
                eventListView: eventListView,
                nextDayEventListView: nextDayView,
                viewAppearance: appearance
            ),
            viewAppearance: appearance
        )
        return HostedViewController(viewController: viewController)
            .onAppear {
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            }
    }

    @MainActor
    func makeSingleColumnView(_ theme: SnapshotTheme) -> some View {
        let appearance = self.makeAppearance(theme, customTags: [])
        appearance.rowHeightOnCalendar = .medium
        let monthViewModel = DummyMonthViewModel()
        let eventListViewModel = self.makeDayEventListViewModel()
        let monthState = MonthViewState()
        monthState.bind(monthViewModel, appearance)
        let eventListState = DayEventListViewState()
        eventListState.bind(eventListViewModel, appearance)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        return ScrollView {
            VStack {
                MonthView()
                    .environment(monthState)
                    .environment(MonthViewEventHandler())
                DayEventListView()
                    .environment(eventListState)
                    .environment(PendingCompleteTodoState())
                    .environment(DayEventListViewEventHandler())
            }
        }
        .background(appearance.colorSet.bg0.asColor)
        .environment(appearance)
    }

    func makeDayEventListViewModel() -> FakeDayEventListViewModel {
        return FakeDayEventListViewModel(
            dayModel: SelectedDayModel(dateText: "Sep 13, 2023 (Wed)", lunarDateText: ""),
            cellModels: [
                ScheduleEventCellViewModel("standup", name: "team standup")
                    |> \.periodText .~ .singleText(.init(text: "9:00", pmOram: "AM")),
                TodoEventCellViewModel("todo", name: "buy groceries")
                    |> \.periodText .~ .currentTodoText
            ]
        )
    }

    @MainActor
    func makeAppearance(_ theme: SnapshotTheme, customTags: [CustomEventTag]) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let appearance = ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
        let defaultTags: [any EventTag] = [
            DefaultEventTag.default("#ff00ff"),
            DefaultEventTag.holiday("#ff0000")
        ]
        appearance.updateEventColorMap(by: defaultTags + customTags)
        return appearance
    }

    func dayListContent() -> ShareImageContentModel {
        var todo = TodoEventCellViewModel("todo-1", name: "장보기")
        todo.periodText = .currentTodoText
        todo.colorSource = EventTagId.custom("personal")

        var standup = ScheduleEventCellViewModel("sc-1", name: "팀 스탠드업")
        standup.periodText = .singleText(.init(text: "09:00"))
        standup.colorSource = EventTagId.custom("work")

        var review = ScheduleEventCellViewModel("sc-2", name: "디자인 리뷰")
        review.periodText = .doubleText(.init(text: "13:00"), .init(text: "14:30"))
        review.periodDescription = "1시간 30분"
        review.colorSource = EventTagId.custom("work")

        return .list([
            ShareImageListSection(
                dayStart: nil, dayHeaderText: nil,
                lines: [ShareImageListLine(eventId: "todo-1", cellViewModel: todo, isExcluded: false)]
            ),
            ShareImageListSection(
                dayStart: 0, dayHeaderText: nil,
                lines: [
                    ShareImageListLine(eventId: "sc-1", cellViewModel: standup, isExcluded: false),
                    ShareImageListLine(eventId: "sc-2", cellViewModel: review, isExcluded: true)
                ]
            )
        ])
    }
}


private struct HostedViewController: UIViewControllerRepresentable {

    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        return self.viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}
