//
//  NextDayEventListViewEventHandlerTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Combine
import Domain
import Scenes

@testable import CalendarScenes
import CalendarPresentation


struct NextDayEventListViewEventHandlerTests {

    @Test func eventHandler_whenBound_forwardCellActionsToHandler() {
        // given
        let spyHandler = SpyEventListCellEventHanleViewModel()
        let eventHandler = NextDayEventListViewEventHandler()
        eventHandler.bind(spyHandler)
        let cell = ScheduleEventCellViewModel("schedule-1", name: "schedule")

        // when
        eventHandler.requestDoneTodo("todo-done")
        eventHandler.requestCancelDoneTodo("todo-cancel")
        eventHandler.requestShowDetail(cell)
        eventHandler.handleMoreAction(cell, .edit)

        // then
        #expect(spyHandler.didDoneTodoId == "todo-done")
        #expect(spyHandler.didCancelDoneTodoId == "todo-cancel")
        #expect(spyHandler.didSelectEventId == cell.eventIdentifier)
        #expect(spyHandler.didHandleMoreAction?.0 == cell.eventIdentifier)
        #expect(spyHandler.didHandleMoreAction?.1 == .edit)
    }
}


// MARK: - doubles

private final class SpyEventListCellEventHanleViewModel: EventListCellEventHanleViewModel {

    var didSelectEventId: String?
    func selectEvent(_ model: any EventCellViewModel) {
        self.didSelectEventId = model.eventIdentifier
    }

    var didDoneTodoId: String?
    func doneTodo(_ eventId: String) {
        self.didDoneTodoId = eventId
    }

    var didCancelDoneTodoId: String?
    func cancelDoneTodo(_ eventId: String) {
        self.didCancelDoneTodoId = eventId
    }

    var didHandleMoreAction: (String, EventListMoreAction)?
    func handleMoreAction(_ cellViewModel: any EventCellViewModel, _ action: EventListMoreAction) {
        self.didHandleMoreAction = (cellViewModel.eventIdentifier, action)
    }

    var doneTodoResult: AnyPublisher<DoneTodoResult, Never> {
        return Empty().eraseToAnyPublisher()
    }

    func eventDetail(copyFromTodo params: TodoMakeParams, detail: EventDetailData?) { }
    func eventDetail(copyFromSchedule schedule: ScheduleMakeParams, detail: EventDetailData?) { }
    func eventDetail(transformTo schedule: ScheduleEvent) { }
    func eventDetail(transformTo todo: TodoEvent) { }
}
