//
//  Scenes+EventDetail.swift
//  Scenes
//
//  Created by sudo.park on 10/29/23.
//

import Foundation
import Domain

public protocol EventDetailScene: Scene { }

public protocol EventDetailSceneListener: AnyObject {
    
    func eventDetail(copyFromTodo params: TodoMakeParams, detail: EventDetailData?)
    func eventDetail(copyFromSchedule schedule: ScheduleMakeParams, detail: EventDetailData?)
}

public struct MakeEventParams: Sendable {
    
    public enum MakeSource: Sendable {
        case todo(withName: String?)
        case schedule
        case todoFromCopy(TodoMakeParams, EventDetailData)
        case scheduleFromCopy(ScheduleMakeParams, EventDetailData)
    }
    
    public struct InitialTodoInfo: Sendable {
        public var name: String?
        public init(name: String? = nil) {
            self.name = name
        }
    }
    public let selectedDate: Date
    public var initialTodoInfo: InitialTodoInfo?
    public init(selectedDate: Date) {
        self.selectedDate = selectedDate
    }
}

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
}
