//
//  CalendarTwoColumnsRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol CalendarTwoColumnsRouting: Routing, Sendable {

    func showSharePreview(range: Range<TimeInterval>, kind: CalendarShareRangeKind)
}

// MARK: - Router

final class CalendarTwoColumnsRouter: BaseRouterImple, CalendarTwoColumnsRouting, @unchecked Sendable {

    private let sharePreviewSceneBuilder: any SharePreviewSceneBuilder

    init(sharePreviewSceneBuilder: any SharePreviewSceneBuilder) {
        self.sharePreviewSceneBuilder = sharePreviewSceneBuilder
    }
}


extension CalendarTwoColumnsRouter {

    func showSharePreview(range: Range<TimeInterval>, kind: CalendarShareRangeKind) {
        Task { @MainActor in
            let next = self.sharePreviewSceneBuilder.makeSharePreviewScene(range: range, kind: kind)
            self.scene?.present(next, animated: true)
        }
    }
}
