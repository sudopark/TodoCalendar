//
//  Scenes+WidgetGallery.swift
//  WidgetGallerySceneInterface
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SceneInfra
import SettingDomainInterface


// MARK: - WidgetGalleryScene Interactable & Listenable

public protocol WidgetGallerySceneInteractor: AnyObject { }


// MARK: - WidgetGalleryScene

public protocol WidgetGalleryScene: Scene where Interactor == any WidgetGallerySceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol WidgetGallerySceneBuilder: AnyObject {
    
    @MainActor
    func makeWidgetGalleryScene(
        setting: WidgetAppearanceSettings
    ) -> any WidgetGalleryScene
}
