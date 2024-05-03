//
//  
//  SelectEventTimeScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - SelectEventTimeScene Interactable & Listenable

protocol SelectEventTimeSceneInteractor: AnyObject { }
//
protocol SelectEventTimeSceneListener: AnyObject {
    
    func select(eventTime: SelectedTime?)
}

// MARK: - SelectEventTimeScene

protocol SelectEventTimeScene: Scene where Interactor == any SelectEventTimeSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventTimeSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventTimeScene(
        startWith previousTime: SelectedTime?,
        at timeZone: TimeZone
    ) -> any SelectEventTimeScene
}
