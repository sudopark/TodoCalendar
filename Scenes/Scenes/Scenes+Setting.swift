//
//  Scenes+Setting.swift
//  Scenes
//
//  Created by sudo.park on 2023/09/24.
//

import UIKit
import Domain


// MARK: - EventTagDetailScene Interactable & Listenable

public struct OriginalTagInfo {
    public let id: AllEventTagId
    public let name: String
    public let color: EventTagColor
    
    public init(id: AllEventTagId, name: String, color: EventTagColor) {
        self.id = id
        self.name = name
        self.color = color
    }
}

public protocol EventTagDetailSceneInteractor: AnyObject { }
//
public protocol EventTagDetailSceneListener: AnyObject {
    
    func eventTag(deleted tagId: String)
    func eventTag(created newTag: EventTag)
    func eventTag(updated newTag: EventTag)
}

// MARK: - EventTagDetailScene

public protocol EventTagDetailScene: Scene where Interactor == any EventTagDetailSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol EventTagDetailSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventTagDetailScene(
        originalInfo: OriginalTagInfo?,
        listener: (any EventTagDetailSceneListener)?
    ) -> any EventTagDetailScene
}

// MARK: - EventTagListScene Interactable & Listenable

public protocol EventTagListSceneInteractor: AnyObject { }
//
public protocol EventTagListSceneListener: EventTagDetailSceneListener { }

// MARK: - EventTagListScene

public protocol EventTagListScene: Scene where Interactor == any EventTagListSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol EventTagListSceneBuiler: AnyObject {
    
    @MainActor
    func makeEventTagListScene(
        listener: (any EventTagListSceneListener)?
    ) -> any EventTagListScene
}

// MARK: - SettingItemListScene Interactable & Listenable

public protocol SettingItemListSceneInteractor: AnyObject { }
//
//public protocol SettingItemListSceneListener: AnyObject { }

// MARK: - SettingItemListScene

public protocol SettingItemListScene: Scene where Interactor == any SettingItemListSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

public protocol SettingItemListSceneBuiler: AnyObject {
    
    @MainActor
    func makeSettingItemListScene() -> any SettingItemListScene
}


// MARK: - setting scene builder

public protocol SettingSceneBuiler: EventTagDetailSceneBuiler, EventTagListSceneBuiler, SettingItemListSceneBuiler { }
