//
//  WidgetPreviewStyleStack.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


struct WidgetPreviewStyleStack {

    private enum Constant {
        static let maxOverlayCount: Int = 2
    }

    let base: any WidgetStyleSetting
    let overlays: [any WidgetStyleSetting]

    init?(styles: [any WidgetStyleSetting]) {
        guard let base = styles.first else { return nil }
        self.base = base
        self.overlays = Array(styles.dropFirst().prefix(Constant.maxOverlayCount))
    }
}
