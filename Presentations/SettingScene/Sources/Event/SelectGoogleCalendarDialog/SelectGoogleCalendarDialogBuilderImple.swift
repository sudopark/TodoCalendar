//
//  SelectGoogleCalendarDialogBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 11/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import CommonPresentation
import SceneInfra


// MARK: - SelectGoogleCalendarDialogSceneBuilerImple

final class SelectGoogleCalendarDialogSceneBuilerImple {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance

    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension SelectGoogleCalendarDialogSceneBuilerImple: SelectGoogleCalendarDialogSceneBuiler {

    @MainActor
    func makeSelectGoogleCalendarDialogScene(accountId: String) -> any SelectGoogleCalendarDialogScene {

        let viewModel = SelectGoogleCalendarDialogViewModelImple(
            accountId: accountId,
            googleCalendarUsecase: self.usecaseFactory.makeGoogleCalendarUsecase(),
            eventTagUsecase: self.usecaseFactory.makeEventTagUsecase()
        )

        let viewController = SelectGoogleCalendarDialogViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )

        let router = SelectGoogleCalendarDialogRouter()
        router.scene = viewController
        viewModel.router = router

        return viewController
    }
}
