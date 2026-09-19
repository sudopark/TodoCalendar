//
//  EventListStyleSetting.swift
//  Domain
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


/// 배경색만 꾸미는 위젯군이라 항목이 없다 — 그래도 스타일 좌표를 가지려면 타입이 있어야 한다.
public struct EventListStyleSetting: WidgetStyleSetting {

    public static let initial = EventListStyleSetting()

    public init() { }
}
