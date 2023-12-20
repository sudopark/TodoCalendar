//
//  
//  CountrySelectScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 12/1/23.
//
//

import UIKit
import Scenes


// MARK: - CountrySelectScene Interactable & Listenable

protocol CountrySelectSceneInteractor: AnyObject { }
//
//public protocol CountrySelectSceneListener: AnyObject { }

// MARK: - CountrySelectScene

protocol CountrySelectScene: Scene where Interactor == any CountrySelectSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol CountrySelectSceneBuiler: AnyObject {
    
    @MainActor
    func makeCountrySelectScene() -> any CountrySelectScene
}
