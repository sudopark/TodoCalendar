//
//  TodayStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct TodayStyleSetting: WidgetStyleSetting {

    public var showHolidayName: Bool?
    public var showTimeZone: Bool?
    public var showTotalCount: Bool?
    public var showTodoCount: Bool?
    public var showScheduleCount: Bool?

    public init() { }
}
