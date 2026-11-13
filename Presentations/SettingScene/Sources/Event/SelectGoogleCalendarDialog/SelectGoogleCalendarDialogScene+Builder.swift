//
//  SelectGoogleCalendarDialogScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SceneInfra


// MARK: - SelectGoogleCalendarDialogScene Interactable & Listenable

protocol SelectGoogleCalendarDialogSceneInteractor: AnyObject { }


// MARK: - SelectGoogleCalendarDialogScene

protocol SelectGoogleCalendarDialogScene: Scene where Interactor == any SelectGoogleCalendarDialogSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectGoogleCalendarDialogSceneBuiler: AnyObject {

    @MainActor
    func makeSelectGoogleCalendarDialogScene(accountId: String) -> any SelectGoogleCalendarDialogScene
}
