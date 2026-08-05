//
//  TimeInterval+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - 카운트다운 표기

extension TimeInterval {

    private enum Constant {
        static let minute: TimeInterval = 60
        static let hour: TimeInterval = 60 * 60
        static let day: TimeInterval = 24 * 60 * 60
    }

    // 남은 시간을 큰 단위 2개까지로 — 1일 초과: 일+시간 / 1시간 초과: 시간+분 / 그 이하: 분+초·초
    private var countdownUnits: NSCalendar.Unit {
        if self > Constant.day { return [.day, .hour] }
        if self > Constant.hour { return [.hour, .minute] }
        if self > Constant.minute { return [.minute, .second] }
        return [.second]
    }

    // 표기가 바뀌는 간격 — 이 주기로만 다시 그리면 충분하다
    public var countdownTickInterval: TimeInterval {
        if self > Constant.day { return Constant.hour }
        if self > Constant.hour { return Constant.minute }
        return 1
    }

    // 단위 문구는 로케일이 만든다. 남은 시간이 없으면 nil
    public func countdownText(locale: Locale = .current) -> String? {
        guard self > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian); calendar.locale = locale
        formatter.calendar = calendar
        formatter.allowedUnits = self.countdownUnits
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: self.rounded(.up))
    }
}
