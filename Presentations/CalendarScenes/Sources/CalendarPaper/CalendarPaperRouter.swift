//
//  
//  CalendarPaperRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - Routing

protocol CalendarPaperRouting: Routing, Sendable {

    func showSharePreview(range: Range<TimeInterval>)
}

// MARK: - Router

final class CalendarPaperRouter: BaseRouterImple, CalendarPaperRouting, @unchecked Sendable {

    private let sharePreviewSceneBuilder: any SharePreviewSceneBuilder

    init(sharePreviewSceneBuilder: any SharePreviewSceneBuilder) {
        self.sharePreviewSceneBuilder = sharePreviewSceneBuilder
    }
}


extension CalendarPaperRouter {

    private var currentScene: (any CalendarPaperScene)? {
        self.scene as? (any CalendarPaperScene)
    }

    func showSharePreview(range: Range<TimeInterval>) {
        Task { @MainActor in
            let next = self.sharePreviewSceneBuilder.makeSharePreviewScene(range: range)
            self.scene?.present(next, animated: true)
        }
    }
}
