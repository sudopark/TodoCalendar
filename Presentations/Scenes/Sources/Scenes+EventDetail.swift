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
        case todoFromCopy(TodoMakeParams, EventDetailData?)
        case scheduleFromCopy(ScheduleMakeParams, EventDetailData?)
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
