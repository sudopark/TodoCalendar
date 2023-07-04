//
//  CalendarPagerViewRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/30.
//

import Foundation
import Domain

protocol CalendarPagerViewRouting: Sendable, AnyObject {
    
    func attachInitialMonths(_ months: [CalendarMonth]) -> [CalendarInteractor]
}
