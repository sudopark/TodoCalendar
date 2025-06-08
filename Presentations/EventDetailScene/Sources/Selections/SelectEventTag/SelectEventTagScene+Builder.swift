//
//  
//  SelectEventTagScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Domain
import Extensions
import Scenes


// MARK: - SelectedTag

struct SelectedTag: Equatable {
    let tagId: EventTagId
    let name: String
    let colorHex: String?
    
    init(
        _ tagId: EventTagId,
        _ name: String,
        _ colorHex: String
    ) {
        self.tagId = tagId
        self.name = name
        self.colorHex = colorHex
    }
    
    init(_ tag: any EventTag) {
        self.tagId = tag.tagId
        self.name = tag.name
        self.colorHex = tag.colorHex
    }
}


// MARK: - SelectEventTagScene Interactable & Listenable

protocol SelectEventTagSceneInteractor: AnyObject, EventTagDetailSceneListener, EventTagListSceneListener { }
//
protocol SelectEventTagSceneListener: AnyObject, Sendable {
    
    func selectEventTag(didSelected tag: SelectedTag)
}

// MARK: - SelectEventTagScene

protocol SelectEventTagScene: Scene where Interactor == any SelectEventTagSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventTagSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventTagScene(
        startWith initail: EventTagId,
        listener: (any SelectEventTagSceneListener)?
    ) -> any SelectEventTagScene
}
