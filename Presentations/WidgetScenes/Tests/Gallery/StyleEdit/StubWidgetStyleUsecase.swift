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
    
    var stubStyles: [WidgetStyle<TodayStyleSetting>] = []
    
    private(set) var requestedVariant: WidgetVariant?
    private(set) var updatedStyles: [WidgetStyle<TodayStyleSetting>] = []
    private(set) var removedStyleIds: [WidgetStyleId] = []
    private var mintedStyleIdCount: Int = 0
    
    func loadStyles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> [WidgetStyle<S>] {
        self.requestedVariant = variant
        return self.stubStyles as? [WidgetStyle<S>] ?? []
    }
    
    func updateStyle<S: WidgetStyleSetting>(_ style: WidgetStyle<S>) {
        guard let updated = style as? WidgetStyle<TodayStyleSetting> else { return }
        self.updatedStyles.append(updated)
        self.stubStyles = self.stubStyles.map { $0.id == updated.id ? updated : $0 }
    }
    
    func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId {
        self.mintedStyleIdCount += 1
        return .init(variant: variant, style: .custom(id: "new\(self.mintedStyleIdCount)"))
    }
    
    func removeStyle(_ id: WidgetStyleId) {
        self.removedStyleIds.append(id)
        self.stubStyles = self.stubStyles.filter { $0.id != id }
    }
}
