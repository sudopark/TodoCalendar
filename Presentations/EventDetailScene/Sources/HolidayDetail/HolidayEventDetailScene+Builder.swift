//
//  
//  HolidayEventDetailScene+Builder.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes


// MARK: - Builder + DependencyInjector Extension

public protocol HolidayEventDetailSceneBuiler: AnyObject {
    
    @MainActor
    func makeHolidayEventDetailScene(uuid: String) -> any HolidayEventDetailScene
}
