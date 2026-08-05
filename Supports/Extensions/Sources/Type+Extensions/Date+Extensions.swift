//
//  Date+extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/04/11.
//

import Foundation


extension Date {
    
    public func add(days: Int) -> Date? {
        var addingComponents = DateComponents()
        addingComponents.day = days
        return Calendar(identifier: .gregorian).date(byAdding: addingComponents, to: self)
    }
    
    public func text(_ form: String, timeZone: TimeZone = .current) -> String {
        let format = DateFormatter(); format.timeZone = timeZone
        format.dateFormat = form
        return format.string(from: self)
    }

    // deadline 까지 카운트다운할 때 다음으로 표기가 바뀌는 시각.
    // deadline 에 정렬돼 단위 경계에 정확히 걸린다. 이미 지났으면 nil
    public func nextCountdownTick(until deadline: Date) -> Date? {
        let remaining = deadline.timeIntervalSince(self)
        guard remaining > 0 else { return nil }
        let interval = remaining.countdownTickInterval
        let steps = max(0, (remaining / interval).rounded(.up) - 1)
        return deadline.addingTimeInterval(-steps * interval)
    }
}
