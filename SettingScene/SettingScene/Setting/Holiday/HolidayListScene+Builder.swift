//
//  
//  HolidayListScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//

import UIKit
import Scenes


// MARK: - HolidayListScene Interactable & Listenable

protocol HolidayListSceneInteractor: AnyObject { }
//
//public protocol HolidayListSceneListener: AnyObject { }

// MARK: - HolidayListScene

protocol HolidayListScene: Scene where Interactor == any HolidayListSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol HolidayListSceneBuiler: AnyObject {
    
    @MainActor
    func makeHolidayListScene() -> any HolidayListScene
}
