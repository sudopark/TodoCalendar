//
//  SpyEventDetailRouter.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 11/6/23.
//

import Foundation
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


final class SpyEventDetailInputInteractor: EventDetailInputInteractor {
    
    var didPreparedWith: (EventDetailBasicData, EventDetailData)?
    var didPreparedCallback: (() -> Void)?
    func prepared(basic: EventDetailBasicData, additional: EventDetailData) {
        self.didPreparedWith = (basic, additional)
        self.didPreparedCallback?()
    }
}

final class SpyEventDetailRouter: BaseSpyRouter, EventDetailRouting, @unchecked Sendable {
    
    var didAttachInput: Bool?
    var spyInteractor: SpyEventDetailInputInteractor = .init()
    func attachInput(
        _ listener: (EventDetailInputListener)?
    ) -> (EventDetailInputInteractor)? {
        self.didAttachInput = true
        return self.spyInteractor
    }
    
    func showTodoEventGuide() {
        
    }
    
    func showForemostEventGuide() {
        
    }
}

final class SpyEventDetailListener: EventDetailSceneListener {
    
    var didCopyCallback: (() -> Void)?
    
    var didRequestCopyFromTodo: (TodoMakeParams, EventDetailData?)?
    func eventDetail(
        copyFromTodo params: TodoMakeParams,
        detail: EventDetailData?
    ) {
        self.didRequestCopyFromTodo = (params, detail)
        self.didCopyCallback?()
    }
    
    var didRequestCopyFromSchedule: (ScheduleMakeParams, EventDetailData?)?
    func eventDetail(
        copyFromSchedule schedule: ScheduleMakeParams,
        detail: EventDetailData?
    ) {
        self.didRequestCopyFromSchedule = (schedule, detail)
        self.didCopyCallback?()
    }
}
