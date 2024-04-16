//
//  MemberSceneBuilderImple.swift
//  MemberScenes
//
//  Created by sudo.park on 2/29/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


public final class MemberSceneBuilderImple: MemberSceneBuilder {
    
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    public init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}

extension MemberSceneBuilderImple {
    
    @MainActor
    public func makeSignInScene() -> any SignInScene {
        let builder = SignInSceneBuilerImple(
            usecaseFactory: self.usecaseFactory, viewAppearance: self.viewAppearance
        )
        return builder.makeSignInScene()
    }
    
    @MainActor
    public func makeMangeAccountScene() -> any ManageAccountScene {
        let builder = ManageAccountSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        return builder.makeManageAccountScene()
    }
}
