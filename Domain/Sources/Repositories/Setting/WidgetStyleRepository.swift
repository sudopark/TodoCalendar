//
//  WidgetStyleRepository.swift
//  Domain
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol WidgetStyleRepository: Sendable {

    func loadSetting(for id: WidgetStyleId) -> (any WidgetStyleSetting)?

    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle]

    func updateStyle(_ style: WidgetStyle)

    func removeStyle(_ id: WidgetStyleId)
}
