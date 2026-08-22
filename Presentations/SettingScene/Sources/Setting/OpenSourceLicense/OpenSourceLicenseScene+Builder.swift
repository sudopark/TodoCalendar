//
//  OpenSourceLicenseScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Scenes


// MARK: - OpenSourceLicenseScene Interactable & Listenable

protocol OpenSourceLicenseSceneInteractor: AnyObject { }

// MARK: - OpenSourceLicenseScene

protocol OpenSourceLicenseScene: Scene where Interactor == any OpenSourceLicenseSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol OpenSourceLicenseSceneBuiler: AnyObject {
    
    @MainActor
    func makeOpenSourceLicenseScene() -> any OpenSourceLicenseScene
}
