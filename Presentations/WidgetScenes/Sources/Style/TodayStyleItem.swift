//
//  TodayStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


/// Today 위젯이 켜고 끌 수 있는 표시 항목 — 나열 순서는 위젯 뷰의 위에서 아래 순이다.
enum TodayStyleItem: String, CaseIterable {

    case showHolidayName
    case showTimeZone
    case showTotalCount
    case showTodoCount
    case showScheduleCount

    var settingKeyPath: WritableKeyPath<TodayStyleSetting, Bool?> {
        switch self {
        case .showHolidayName: return \.showHolidayName
        case .showTimeZone: return \.showTimeZone
        case .showTotalCount: return \.showTotalCount
        case .showTodoCount: return \.showTodoCount
        case .showScheduleCount: return \.showScheduleCount
        }
    }

    /// 값 자체가 상황에 따라 없을 수 있는 항목만 부연을 갖는다.
    var note: String? {
        switch self {
        case .showHolidayName: return "widget.style.today::showHolidayName::note".localized()
        case .showTimeZone: return "widget.style.today::showTimeZone::note".localized()
        case .showTotalCount, .showTodoCount, .showScheduleCount: return nil
        }
    }

    var name: String {
        switch self {
        case .showHolidayName: return "widget.style.today::showHolidayName".localized()
        case .showTimeZone: return "widget.style.today::showTimeZone".localized()
        case .showTotalCount: return "widget.style.today::showTotalCount".localized()
        case .showTodoCount: return "widget.style.today::showTodoCount".localized()
        case .showScheduleCount: return "widget.style.today::showScheduleCount".localized()
        }
    }
}


// MARK: - 스타일 항목 기본값

extension Optional where Wrapped == Bool {

    /// 스타일 항목은 미설정(nil)이면 표시가 기본이다.
    var isDisplayed: Bool { self != false }
}
