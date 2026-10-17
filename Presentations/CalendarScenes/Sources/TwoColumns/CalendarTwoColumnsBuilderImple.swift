//
//  CalendarTwoColumnsBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - CalendarTwoColumnsBuilderImple

final class CalendarTwoColumnsBuilderImple {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventListSceneBuilder: any DayEventListSceneBuiler
    private let eventListCellEventHanleViewModelBuilder: any EventListCellEventHanleViewModelBuilder
    private let sharePreviewSceneBuilder: any SharePreviewSceneBuilder
    private let pendingCompleteTodoState: PendingCompleteTodoState

    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventListSceneBuilder: any DayEventListSceneBuiler,
        eventListCellEventHanleViewModelBuilder: any EventListCellEventHanleViewModelBuilder,
        sharePreviewSceneBuilder: any SharePreviewSceneBuilder,
        pendingCompleteTodoState: PendingCompleteTodoState
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventListSceneBuilder = eventListSceneBuilder
        self.eventListCellEventHanleViewModelBuilder = eventListCellEventHanleViewModelBuilder
        self.sharePreviewSceneBuilder = sharePreviewSceneBuilder
        self.pendingCompleteTodoState = pendingCompleteTodoState
    }
}


extension CalendarTwoColumnsBuilderImple: CalendarTwoColumnsSceneBuilder {

    @MainActor
    func makeTwoColumnsScene(
        initialMonth: CalendarMonth,
        listener: (any CalendarTwoColumnsSceneListener)?
    ) -> any CalendarTwoColumnsScene {

        let monthsViewModel = self.makeContinuousMonthsViewModel(initialMonth)
        let eventListComponents = self.eventListSceneBuilder.makeSceneComponent()
        let nextDayViewModel = NextDayEventListViewModelImple(
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase(),
            foremostEventUsecase: self.usecaseFactory.makeForemostEventUsecase(),
            eventLiveActivityUsecase: self.usecaseFactory.eventLiveActivityUsecase,
            ddayCandidateUsecase: self.usecaseFactory.makeDDayCandidateUsecase()
        )
        let viewModel = CalendarTwoColumnsViewModelImple(
            continuousMonthsInteractor: monthsViewModel,
            eventListInteractor: eventListComponents.viewModel,
            nextDayInteractor: nextDayViewModel
        )
        viewModel.listener = listener
        monthsViewModel.attachListener(viewModel)
        eventListComponents.viewModel.attachListener(viewModel)

        let cellEventHandleViewModel = self.eventListCellEventHanleViewModelBuilder.viewModel
        let eventListEventHandler = DayEventListViewEventHandler()
        eventListEventHandler.bind(eventListComponents.viewModel, cellEventHandleViewModel)
        let eventListView = DayEventListContainerView(
            viewAppearance: self.viewAppearance,
            eventHandler: eventListEventHandler,
            pendingDoneState: self.pendingCompleteTodoState
        )
        .eventHandler(\.stateBinding, { [viewAppearance] in $0.bind(eventListComponents.viewModel, viewAppearance) })

        let nextDayEventHandler = NextDayEventListViewEventHandler()
        nextDayEventHandler.bind(cellEventHandleViewModel)
        let nextDayView = NextDayEventListContainerView(
            viewAppearance: self.viewAppearance,
            eventHandler: nextDayEventHandler,
            pendingDoneState: self.pendingCompleteTodoState
        )
        .eventHandler(\.stateBinding, { [viewAppearance] in $0.bind(nextDayViewModel, viewAppearance) })

        let viewController = CalendarTwoColumnsViewController(
            viewModel: viewModel,
            monthsViewController: ContinuousMonthsViewController(
                viewModel: monthsViewModel, viewAppearance: self.viewAppearance
            ),
            listView: CalendarTwoColumnsListContainerView(
                eventListView: eventListView,
                nextDayEventListView: nextDayView,
                viewAppearance: self.viewAppearance
            ),
            viewAppearance: self.viewAppearance
        )
        (eventListComponents.router as? BaseRouterImple)?.scene = viewController

        let router = CalendarTwoColumnsRouter(sharePreviewSceneBuilder: self.sharePreviewSceneBuilder)
        router.scene = viewController
        viewModel.router = router

        return viewController
    }

    private func makeContinuousMonthsViewModel(_ initialMonth: CalendarMonth) -> ContinuousMonthsViewModelImple {
        let calendarSettingUsecase = self.usecaseFactory.makeCalendarSettingUsecase()
        let tagUsecase = self.usecaseFactory.makeEventTagUsecase()
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        let eventListUsecase = CalendarEventListhUsecaseImple(
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            appleCalendarUsecase: self.usecaseFactory.makeAppleCalendarUsecase(),
            foremostEventUsecase: self.usecaseFactory.makeForemostEventUsecase(),
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: tagUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        return ContinuousMonthsViewModelImple(
            initialMonth: initialMonth,
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: calendarSettingUsecase,
            eventListUsecase: eventListUsecase,
            eventTagUsecase: tagUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
    }
}
