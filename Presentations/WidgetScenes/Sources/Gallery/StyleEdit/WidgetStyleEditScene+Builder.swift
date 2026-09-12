//
//  WidgetStyleEditScene+Builder.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes


// MARK: - interactor

protocol WidgetStyleEditSceneInteractor: AnyObject { }
//

// MARK: - scene

protocol WidgetStyleEditScene: Scene where Interactor == any WidgetStyleEditSceneInteractor
{ }


// MARK: - builder

protocol WidgetStyleEditSceneBuilder: AnyObject {
    
    @MainActor
    func makeWidgetStyleEditScene(
        variant: WidgetVariant,
        setting: WidgetAppearanceSettings
    ) -> any WidgetStyleEditScene
}
