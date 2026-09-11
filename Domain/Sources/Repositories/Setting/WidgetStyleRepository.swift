//
//  WidgetStyleRepository.swift
//  Domain
//
//  Created by sudo.park on 9/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol WidgetStyleRepository: Sendable {

    func loadSetting<S: WidgetStyleSetting>(_ type: S.Type, for id: WidgetStyleId) -> S?

    func loadStyles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> [WidgetStyle<S>]

    func updateSetting<S: WidgetStyleSetting>(_ setting: S, for id: WidgetStyleId)

    func removeStyle(_ id: WidgetStyleId)
}
