//
//  CalendarInteractor.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/28.
//

import Foundation
import Domain


protocol CalendarInteractor: Sendable {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
}
