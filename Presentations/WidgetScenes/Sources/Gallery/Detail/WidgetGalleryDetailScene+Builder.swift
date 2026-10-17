//
//  WidgetGalleryDetailScene+Builder.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes


// MARK: - interactor

protocol WidgetGalleryDetailSceneInteractor: AnyObject { }
//

// MARK: - scene

protocol WidgetGalleryDetailScene: Scene where Interactor == any WidgetGalleryDetailSceneInteractor
{ }


// MARK: - builder

protocol WidgetGalleryDetailSceneBuilder: AnyObject {
    
    @MainActor
    func makeWidgetGalleryDetailScene(
        item: WidgetGalleryItem,
        setting: WidgetAppearanceSettings
    ) -> any WidgetGalleryDetailScene
}
