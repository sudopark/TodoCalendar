//
//  StubWidgetStyleUsecase.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


final class StubWidgetStyleUsecase: WidgetStyleUsecase, @unchecked Sendable {
    
    var stubStyles: [Any] = []
    
    private(set) var requestedVariant: WidgetVariant?
    private(set) var updatedSetting: Any?
    private(set) var updatedStyleId: WidgetStyleId?
    
    func loadStyles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> [WidgetStyle<S>] {
        self.requestedVariant = variant
        return self.stubStyles.compactMap { $0 as? WidgetStyle<S> }
    }
    
    func updateStyle<S: WidgetStyleSetting>(_ setting: S, for id: WidgetStyleId) {
        self.updatedSetting = setting
        self.updatedStyleId = id
    }
}
