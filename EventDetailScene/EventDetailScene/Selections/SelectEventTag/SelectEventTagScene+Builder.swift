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
import Scenes


// MARK: - SelectedTag

struct SelectedTag: Equatable {
    let tagId: AllEventTagId
    let name: String
    let color: EventTagColor
    
    init(
        _ tagId: AllEventTagId,
        _ name: String,
        _ color: EventTagColor
    ) {
        self.tagId = tagId
        self.name = name
        self.color = color
    }
    
    init(_ tag: EventTag) {
        self.tagId = .custom(tag.uuid)
        self.name = tag.name
        self.color = .custom(hex: tag.colorHex)
    }
    
    static var defaultTag: SelectedTag {
        return .init(.default, "default".localized(), .default)
    }
    
    static var holiday: SelectedTag {
        return .init(.holiday, "holiday".localized(), .holiday)
    }
}


// MARK: - SelectEventTagScene Interactable & Listenable

protocol SelectEventTagSceneInteractor: AnyObject { }
//
protocol SelectEventTagSceneListener: AnyObject {
    
    func selectEventTag(didSelected tag: SelectedTag)
}

// MARK: - SelectEventTagScene

protocol SelectEventTagScene: Scene where Interactor == any SelectEventTagSceneInteractor
{ }


// MARK: - Builder + DependencyInjector Extension

protocol SelectEventTagSceneBuiler: AnyObject {
    
    @MainActor
    func makeSelectEventTagScene(
        startWith initail: AllEventTagId
    ) -> any SelectEventTagScene
}
