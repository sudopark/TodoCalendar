//
//  CalendarSceneBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Scenes
import CommonPresentation

public struct CalendarSceneBuilderImple {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    private let eventListSceneBuilder: any EventListSceneBuiler
    private let accountUsecase: any AccountUsecase
    private let memberSceneBuilder: any MemberSceneBuilder
    private let aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder
    private let pendingCompleteTodoState: PendingCompleteTodoState = .init()
    public let calendarDeepLinkHandler = CalendarDeepLinkHandlerImple()
    private let eventDeepLinkHandler = EventDeepLinkHandlerImple()

    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventDetailSceneBuilder: any EventDetailSceneBuilder,
        eventListSceneBuilder: any EventListSceneBuiler,
        accountUsecase: any AccountUsecase,
        memberSceneBuilder: any MemberSceneBuilder,
        aiAgentCommandSceneBuilder: any AIAgentCommandSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
        self.accountUsecase = accountUsecase
        self.memberSceneBuilder = memberSceneBuilder
        self.aiAgentCommandSceneBuilder = aiAgentCommandSceneBuilder
    }

    private var eventListCellEventHanleViewModelBuilder: (any EventListCellEventHanleViewModelBuilder)?
}

extension CalendarSceneBuilderImple: CalendarSceneBuilder {

    @MainActor
    public func makeCalendarScene(
        listener: (any CalendarSceneListener)?
    ) -> any CalendarScene {

        let viewModel = CalendarViewModelImple(
            calendarUsecase: self.usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: self.usecaseFactory.makeCalendarSettingUsecase(),
            holidayUsecase: self.usecaseFactory.makeHolidayUsecase(),
            todoEventUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleEventUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            foremostEventusecase: self.usecaseFactory.makeForemostEventUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            migrationUsecase: self.usecaseFactory.temporaryUserDataMigrationUsecase,
            uiSettingUsecase: self.usecaseFactory.makeUISettingUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            appleCalendarUsecase: self.usecaseFactory.makeAppleCalendarUsecase(),
            eventUploadService: self.usecaseFactory.eventUploadService,
            eventSyncUsecase: self.usecaseFactory.eventSyncUsecase,
            aiAgentOrchestrationUsecase: self.usecaseFactory.makeAIAgentOrchestrationUsecase()
        )
        viewModel.listener = listener
        let viewController = CalendarViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )

        let monthSceneBuilder = MonthSceneBuilderImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        let eventListSceneBuilder = DayEventListSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            eventDetailSceneBuilder: self.eventDetailSceneBuilder,
            eventListSceneBuilder: self.eventListSceneBuilder,
            accountUsecase: self.accountUsecase,
            memberSceneBuilder: self.memberSceneBuilder
        )

        let handleViewModelBuilder = EventListCellEventHanleViewModelBuilderImple(
            usecaseFactory: self.usecaseFactory,
            eventDetailSceneBuilder: self.eventDetailSceneBuilder
        )
        handleViewModelBuilder.router.attach(viewController)
        self.pendingCompleteTodoState.bind(handleViewModelBuilder.viewModel, viewAppearance)

        self.calendarDeepLinkHandler.attach(calendarInteractor: viewModel)
        self.calendarDeepLinkHandler.attach(eventHandler: self.eventDeepLinkHandler)
        self.eventDeepLinkHandler.attach(router: handleViewModelBuilder.router)

        let paperSceneBuilder = CalendarPaperSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            monthSceneBuilder: monthSceneBuilder,
            eventListSceneBuilder: eventListSceneBuilder,
            eventListCellEventHanleViewModelBuilder: handleViewModelBuilder,
            pendingCompleteTodoState: pendingCompleteTodoState
        )
        let router = CalendarViewRouterImple(
            paperSceneBuilder,
            aiAgentCommandSceneBuilder: self.aiAgentCommandSceneBuilder
        )
        router.scene = viewController
        viewModel.router = router

        return viewController
    }
}


extension CalendarSceneBuilderImple {

    @MainActor
    public func makeSelectDialog(
        current: CalendarDay,
        _ listener: (any SelectDayDialogSceneListener)?
    ) -> any SelectDayDialogScene {

        let viewModel = SelectDayDialogViewModelImple(
            currentDay: current,
            calendarUsecase: usecaseFactory.makeCalendarUsecase()
        )
        let viewController = SelectDayDialogViewController(
            viewModel: viewModel, viewAppearance: viewAppearance
        )
        let router = SelectDayDialogRouter()
        router.scene = viewController
        viewModel.router = router
        viewModel.listener = listener

        return viewController
    }
}
