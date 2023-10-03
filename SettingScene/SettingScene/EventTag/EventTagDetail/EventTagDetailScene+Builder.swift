//
//  
//  EventTagDetailScene+Builder.swift
//  SettingScene
//
//  Created by sudo.park on 2023/10/03.
//
//

import UIKit
import Domain
import Scenes


// MARK: - EventTagDetailScene Interactable & Listenable

protocol EventTagDetailSceneInteractor: AnyObject { }
//
protocol EventTagDetailSceneListener: AnyObject { 
    
    func evetTag(deleted tagId: String)
    func eventTag(created newTag: EventTag)
    func eventTag(updated newTag: EventTag)
}

// MARK: - EventTagDetailScene

protocol EventTagDetailScene: Scene where Interactor == any EventTagDetailSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol EventTagDetailSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventTagDetailScene(
        originalInfo: OriginalTagInfo?,
        listener: EventTagDetailSceneListener?
    ) -> any EventTagDetailScene
}
