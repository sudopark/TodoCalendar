//
//  EventDetailSceneBuilderImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/29/23.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


public final class EventDetailSceneBuilderImple {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let eventTagDetailSceneBuilder: any EventTagDetailSceneBuiler
    private let eventTagListSceneBuilder: any EventTagListSceneBuiler
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        eventTagDetailSceneBuilder: any EventTagDetailSceneBuiler,
        eventTagListSceneBuilder: any EventTagListSceneBuiler
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.eventTagDetailSceneBuilder = eventTagDetailSceneBuilder
        self.eventTagListSceneBuilder = eventTagListSceneBuilder
    }
}

extension EventDetailSceneBuilderImple: EventDetailSceneBuilder {
    
    @MainActor
    public func makeNewEventScene(isTodo: Bool) -> any EventDetailScene {
        
        let selectOptionBuilder = SelectEventRepeatOptionSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let selectTagSceneBuilder = SelectEventTagSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            eventTagDetailSceneBuilder: self.eventTagDetailSceneBuilder,
            eventTagListSceneBuilder: self.eventTagListSceneBuilder
        )
        
        let addSceneBuilder = AddEventSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            selectRepeatOptionSceneBuilder: selectOptionBuilder,
            selectEventTagSceneBuilder: selectTagSceneBuilder
        )
        return addSceneBuilder.makeAddEventScene(isTodo: isTodo)
    }
}
