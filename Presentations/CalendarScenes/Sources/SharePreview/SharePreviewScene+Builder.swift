//
//  SharePreviewScene+Builder.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes


// MARK: - SharePreviewScene Interactable

protocol SharePreviewSceneInteractor: AnyObject { }


// MARK: - SharePreviewScene

protocol SharePreviewScene: Scene where Interactor == any SharePreviewSceneInteractor { }


// MARK: - Builder

protocol SharePreviewSceneBuilder: Sendable {

    @MainActor
    func makeSharePreviewScene(range: Range<TimeInterval>) -> any SharePreviewScene
}
