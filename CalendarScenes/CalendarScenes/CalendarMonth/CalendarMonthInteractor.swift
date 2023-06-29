//
//  CalendarMonthInteractor.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/06/28.
//

import Foundation
import Domain


protocol CalendarMonthInteractor: Sendable {
    
    func updateMonthIfNeed(_ newMonth: CalendarMonth)
    func holidayChanged(_ holidays: [Int: [Holiday]])
}
