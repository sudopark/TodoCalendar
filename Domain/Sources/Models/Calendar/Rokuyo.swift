//
//  Rokuyo.swift
//  Domain
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


public enum Rokuyo: Int, CaseIterable, Sendable {
    case taian
    case shakku
    case sensho
    case tomobiki
    case senbu
    case butsumetsu

    init(lunarMonth: Int, lunarDay: Int) {
        self = Rokuyo.allCases[(lunarMonth + lunarDay) % Rokuyo.allCases.count]
    }

    public init?(_ day: CalendarComponent.Day) {
        guard let lunarCalendar = Constant.lunarCalendar,
              let date = Constant.gregorian.date(from: day)
        else { return nil }
        let components = lunarCalendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let lunarDay = components.day
        else { return nil }
        self.init(lunarMonth: month, lunarDay: lunarDay)
    }
}


private enum Constant {
    static let tokyo: TimeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    static let gregorian: Calendar = Calendar(identifier: .gregorian)
        |> \.timeZone .~ tokyo

    // 일본 旧暦은 UTC+9 기준이라 dangi 만 맞는다 — chinese(UTC+8)는 하루씩 어긋나는 구간이 있어 폴백하지 않는다
    static let lunarCalendar: Calendar? = {
        guard #available(iOS 26, *) else { return nil }
        return Calendar(identifier: .dangi) |> \.timeZone .~ tokyo
    }()
}
