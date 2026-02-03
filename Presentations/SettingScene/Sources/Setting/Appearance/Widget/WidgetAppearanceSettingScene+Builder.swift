//
//  WidgetAppearanceSettingScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 2/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes


// MARK: - interactor

protocol WidgetAppearanceSettingSceneInteractor: AnyObject { }
//

// MARK: - scene

protocol WidgetAppearanceSettingScene: Scene where Interactor == any WidgetAppearanceSettingSceneInteractor
{ }


// MARK: - builder

protocol WidgetAppearanceSettingSceneBuilder: AnyObject {
    
    @MainActor
    func makeWidgetAppearanceSettingScene(
        setting: WidgetAppearanceSettings
    ) -> any WidgetAppearanceSettingScene
}

