//
//  TodoItemPlan.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public struct TodoItemPlan {
    
    public let uuid: String
    public var todoName: String
    public var tagId: String?
    public var isRegardAsDoneWhenTimePass: Bool = false
    
    public var planTime: EventPlanTime
    
    public init(uuid: String, todoName: String, planTime: EventPlanTime) {
        self.uuid = uuid
        self.todoName = todoName
        self.planTime = planTime
    }
}
