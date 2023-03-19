//
//  AnniversaryItemPlan.swift
//  Domain
//
//  Created by sudo.park on 2023/03/19.
//

import Foundation


public struct AnniversaryItemPlan {
    
    public let uuid: String
    public var anniversaryName: String
    public var tagId: String?
    public var isCountTurn: Bool = false
    
    public var planTime: EventPlanTime
    
    public init(uuid: String, anniversaryName: String,
                isCountTurn: Bool, planTime: EventPlanTime) {
        self.uuid = uuid
        self.anniversaryName = anniversaryName
        self.isCountTurn = isCountTurn
        self.planTime = planTime
    }
}
