//
//  Scenes+Setting.swift
//  Scenes
//
//  Created by sudo.park on 2023/09/24.
//

import UIKit
import Domain


// MARK: - EventTagDetailScene Interactable & Listenable

public struct OriginalTagInfo: Sendable {
    public let id: EventTagId
    public let name: String
    public let colorHex: String?
    
    public init(id: EventTagId, name: String, colorHex: String?) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

public protocol EventTagDetailSceneInteractor: AnyObject { }
//
public protocol EventTagDetailSceneListener: AnyObject, Sendable {
    
    func eventTag(deleted tagId: EventTagId)
    func eventTag(created newTag: any EventTag)
    func eventTag(updated newTag: any EventTag)
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
        isRootNavigation: Bool,
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
