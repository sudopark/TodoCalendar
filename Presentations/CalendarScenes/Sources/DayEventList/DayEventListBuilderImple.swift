//
//
//  DayEventListBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - DayEventListSceneBuilerImple

final class DayEventListSceneBuilerImple {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    private let eventListSceneBuilder: any EventListSceneBuiler
    private let accountUsecase: any AccountUsecase
    private let memberSceneBuilder: any MemberSceneBuilder
    private let aiKeyboardInputSceneBuilder: any AIAgentKeyboardInputSceneBuilder
    private let aiImageCommandSceneBuilder: any AIAgentImageCommandSceneBuilder

    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventDetailSceneBuilder: any EventDetailSceneBuilder,
        eventListSceneBuilder: any EventListSceneBuiler,
        accountUsecase: any AccountUsecase,
        memberSceneBuilder: any MemberSceneBuilder,
        aiKeyboardInputSceneBuilder: any AIAgentKeyboardInputSceneBuilder,
        aiImageCommandSceneBuilder: any AIAgentImageCommandSceneBuilder
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
        self.accountUsecase = accountUsecase
        self.memberSceneBuilder = memberSceneBuilder
        self.aiKeyboardInputSceneBuilder = aiKeyboardInputSceneBuilder
        self.aiImageCommandSceneBuilder = aiImageCommandSceneBuilder
    }
}


extension DayEventListSceneBuilerImple: DayEventListSceneBuiler {

    func makeSceneComponent() -> DayEventListSceneComponent {
        let calendarSettingUsecase = self.usecaseFactory.makeCalendarSettingUsecase()
        let todoEventUsecase = self.usecaseFactory.makeTodoEventUsecase()
        let foremostEventUsecase = self.usecaseFactory.makeForemostEventUsecase()
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        let eventListUsecase = CalendarEventListhUsecaseImple(
            todoUsecase: todoEventUsecase,
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            appleCalendarUsecase: self.usecaseFactory.makeAppleCalendarUsecase(),
            foremostEventUsecase: foremostEventUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase(),
            uiSettingUsecase: uiSettingUsecase
        )
        let viewModel = DayEventListViewModelImple(
            calendarUsecase: usecaseFactory.makeCalendarUsecase(),
            calendarSettingUsecase: calendarSettingUsecase,
            eventListUsecase: eventListUsecase,
            todoEventUsecase: todoEventUsecase,
            foremostEventUsecase: foremostEventUsecase,
            uiSettingUsecase: uiSettingUsecase,
            accountUsecase: self.accountUsecase,
            aiAgentOrchestrationUsecase: self.usecaseFactory.aiAgentOrchestrationUsecase
        )
        let router = DayEventListRouter(
            eventDetailSceneBuilder: self.eventDetailSceneBuilder,
            eventListSceneBuilder: self.eventListSceneBuilder,
            memberSceneBuilder: self.memberSceneBuilder,
            aiKeyboardInputSceneBuilder: self.aiKeyboardInputSceneBuilder,
            aiImageCommandSceneBuilder: self.aiImageCommandSceneBuilder,
            viewAppearance: self.viewAppearance
        )
        viewModel.router = router
        return .init(viewModel: viewModel, router: router)
    }
}
