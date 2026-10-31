//
//  
//  ManageAccountScene+Builder.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import MemberSceneInterface


// MARK: - Builder + DependencyInjector Extension

protocol ManageAccountSceneBuiler: AnyObject {
    
    @MainActor
    func makeManageAccountScene() -> any ManageAccountScene
}
