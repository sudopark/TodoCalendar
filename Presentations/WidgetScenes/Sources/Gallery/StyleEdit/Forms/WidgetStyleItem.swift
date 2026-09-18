//
//  WidgetStyleItem.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


/// 위젯군이 켜고 끌 수 있는 표시 항목 — 나열 순서는 위젯 뷰의 위에서 아래 순이다.
protocol WidgetStyleItem: CaseIterable, Hashable {

    associatedtype Setting: WidgetStyleSetting

    var settingKeyPath: WritableKeyPath<Setting, Bool> { get }
    var name: String { get }
    var note: String? { get }
}


extension WidgetStyleItem {

    /// 값 자체가 상황에 따라 없을 수 있는 항목만 부연을 갖는다.
    var note: String? { return nil }
}
