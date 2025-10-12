//
//  Scenes+EventDetail.swift
//  Scenes
//
//  Created by sudo.park on 10/29/23.
//

import Foundation
import Prelude
import Optics
import Domain


// MARK: - EventDetail scene

public protocol EventDetailScene: Scene { }

public protocol EventDetailSceneListener: AnyObject {
    
    func eventDetail(copyFromTodo params: TodoMakeParams, detail: EventDetailData?)
    func eventDetail(copyFromSchedule schedule: ScheduleMakeParams, detail: EventDetailData?)
}

public struct MakeEventParams: Sendable {
    
    public enum MakeSource: Sendable {
        case todoWith(TodoMakeParams, EventDetailData?)
        case scheduleWith(ScheduleMakeParams, EventDetailData?)
        case todoFromCopy(_ id: String)
        case scheduleFromCopy(_ id: String)
        
        public static func todo(withName: String?) -> MakeSource {
            let params = TodoMakeParams() |> \.name .~ withName
            return .todoWith(params, nil)
        }
        
        public static func schedule() -> MakeSource {
            return .scheduleWith(.init(), nil)
        }
    }
    
    public let selectedDate: Date
    public let makeSource: MakeSource
    public init(
        selectedDate: Date, makeSource: MakeSource
    ) {
        self.selectedDate = selectedDate
        self.makeSource = makeSource
    }
}

// MARK: - GoogleCalendarEventDetailScene Interactable & Listenable

public protocol GoogleCalendarEventDetailSceneInteractor: AnyObject { }
//
//public protocol GoogleCalendarEventDetailSceneListener: AnyObject { }

// MARK: - GoogleCalendarEventDetailScene

public protocol GoogleCalendarEventDetailScene: Scene where Interactor == any GoogleCalendarEventDetailSceneInteractor
{ }

// MARK: - HolidayEventDetailScene Interactable & Listenable

public protocol HolidayEventDetailSceneInteractor: AnyObject { }
//
//public protocol HolidayEventDetailSceneListener: AnyObject { }

// MARK: - HolidayEventDetailScene

public protocol HolidayEventDetailScene: Scene where Interactor == any HolidayEventDetailSceneInteractor
{ }

// MARK: - EventDetailSceneBuilder

public protocol EventDetailSceneBuilder {
    
    @MainActor
    func makeNewEventScene(_ params: MakeEventParams) -> any EventDetailScene
    
    @MainActor
    func makeTodoEventDetailScene(
        _ todoId: String,
        listener: EventDetailSceneListener?
    ) -> any EventDetailScene
    
    @MainActor
    func makeScheduleEventDetailScene(
        _ scheduleId: String,
        _ repeatingEventTargetTime: EventTime?,
        listener: EventDetailSceneListener?
    ) -> any EventDetailScene
    
    @MainActor
    func makeHolidayEventDetailScene(
        _ uuid: String
    ) -> any HolidayEventDetailScene
    
    @MainActor
    func makeGoogleCalendarDetailScene(
        calendarId: String, eventId: String
    ) -> any GoogleCalendarEventDetailScene
}
