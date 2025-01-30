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
    let tagId: AllEventTagId
    let name: String
    let customColorHex: String?
    
    init(
        _ tagId: AllEventTagId,
        _ name: String,
        _ customColorHex: String?
    ) {
        self.tagId = tagId
        self.name = name
        self.customColorHex = customColorHex
    }
    
    init(_ tag: EventTag) {
        self.tagId = .custom(tag.uuid)
        self.name = tag.name
        self.customColorHex = tag.colorHex
    }
    
    static var defaultTag: SelectedTag {
        return .init(.default, R.String.EventTag.Defaults.defaultName, nil)
    }
    
    static var holiday: SelectedTag {
        return .init(.holiday, R.String.EventTag.Defaults.holidayName, nil)
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
        startWith initail: AllEventTagId,
        listener: (any SelectEventTagSceneListener)?
    ) -> any SelectEventTagScene
}
