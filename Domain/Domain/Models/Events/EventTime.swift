//
//  EventTime.swift
//  Domain
//
//  Created by sudo.park on 2023/03/26.
//

import Foundation


// MARK: - Event time

public enum EventTime {
    case at(Date)
    case period(ClosedRange<Date>)
    case allDays(Range<FixedDate>)
}
