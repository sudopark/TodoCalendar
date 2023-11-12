//
//  Scenes+EventDetail.swift
//  Scenes
//
//  Created by sudo.park on 10/29/23.
//

import Foundation
import Domain


public protocol EventDetailScene: Scene { }

public protocol EventDetailSceneBuilder {
    
    @MainActor
    func makeNewEventScene(isTodo: Bool) -> any EventDetailScene
    
    @MainActor
    func makeTodoEventDetailScene(_ todoId: String) -> any EventDetailScene
}
