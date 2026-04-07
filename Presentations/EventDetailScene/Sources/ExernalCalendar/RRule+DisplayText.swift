//
//  RRule+DisplayText.swift
//  EventDetailScene
//
//  Created by sudo.park on 4/7/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Domain


// MARK: - RRule display text helpers (shared across Google/Apple calendar detail)

extension RRule {

    func frequencyText() -> String {
        switch self.freq {
        case .DAILY where self.interval == 1:
            return "eventDetail.repeating.everyDay:title".localized()

        case .DAILY:
            return "eventDetail.repeating.everyNDays:title".localized(with: self.interval)

        case .WEEKLY where self.interval == 1:
            return "eventDetail.repeating.everyWeek:title".localized()
                .appendDaysText(self.byDays)

        case .WEEKLY:
            return "eventDetail.repeating.everySomeWeek:title".localized(with: self.interval)
                .appendDaysText(self.byDays)

        case .MONTHLY where self.interval == 1:
            return "eventDetail.repeating.everyMonth:title".localized()
                .appendDaysText(self.byDays)

        case .MONTHLY:
            return "eventDetail.repeating.everyNMonths:title".localized(with: self.interval)
                .appendDaysText(self.byDays)

        case .YEARLY where self.interval == 1:
            return "eventDetail.repeating.everyYear:title".localized()

        case .YEARLY:
            return "eventDetail.repeating.everyNYears:title".localized(with: self.interval)
        }
    }

    func endOptionText(_ timeZone: TimeZone) -> String? {
        if let until = self.until {
            let dateText = until.text("date_form.yyyy_MMM_dd".localized(), timeZone: timeZone)
            return "eventDetail.repeating::endoption_until".localized(with: dateText)
        } else if let count = self.count {
            return "eventDetail.repeating::endoption_times".localized(with: count)
        } else {
            return nil
        }
    }
}

extension String {

    func appendDaysText(_ byDays: [RRule.ByDay]) -> String {
        guard !byDays.isEmpty else { return self }
        let texts = byDays
            .sorted(by: RRule.ByDay.compareOrder(_:_:))
            .map { $0.text() }.joined(separator: ",")
        return "\(self) \(texts)"
    }
}

extension RRule.ByDay.WeekDay {

    var sortOrder: Int {
        return switch self {
        case .MO: 1
        case .TU: 2
        case .WE: 3
        case .TH: 4
        case .FR: 5
        case .SA: 6
        case .SU: 7
        }
    }
}

extension RRule.ByDay {

    static func compareOrder(_ lhs: Self, _ rhs: Self) -> Bool {
        if let l_ordinal = lhs.ordinal, let r_ordinal = rhs.ordinal {
            return l_ordinal < r_ordinal
        } else {
            return lhs.weekDay.sortOrder < rhs.weekDay.sortOrder
        }
    }

    func text() -> String {
        switch self.ordinal {
        case .none:
            return self.weekDay.text()
        case .some(let n) where n == -1:
            return "\("eventDetail.repeating.last".localized()) \(self.weekDay.text())"
        case .some(let n):
            return n.ordinal.map { "\($0) \(self.weekDay.text())" } ?? self.weekDay.text()
        }
    }
}

extension RRule.ByDay.WeekDay {

    func text() -> String {
        switch self {
        case .MO: return "dayname::monday:short".localized()
        case .TU: return "dayname::tuesday:short".localized()
        case .WE: return "dayname::wednesday:short".localized()
        case .TH: return "dayname::thursday:short".localized()
        case .FR: return "dayname::friday:short".localized()
        case .SA: return "dayname::saturday:short".localized()
        case .SU: return "dayname::sunday:short".localized()
        }
    }
}
