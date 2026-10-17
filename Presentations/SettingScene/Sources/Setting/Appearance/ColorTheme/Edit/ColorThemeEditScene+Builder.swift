//
//  ColorThemeEditScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes


// MARK: - ColorThemeEditScene Interactable & Listenable

protocol ColorThemeEditSceneInteractor: AnyObject { }

protocol ColorThemeEditSceneListener: AnyObject, Sendable {

    func customColorTheme(saved theme: CustomColorTheme)
    func customColorTheme(removed uuid: String)
}

// MARK: - ColorThemeEditScene

protocol ColorThemeEditScene: Scene where Interactor == any ColorThemeEditSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol ColorThemeEditSceneBuiler: AnyObject {

    @MainActor
    func makeColorThemeEditScene(
        original: CustomColorTheme?,
        listener: (any ColorThemeEditSceneListener)?
    ) -> any ColorThemeEditScene
}
