//
//  OpenSourceLicenseViewController.swift
//  SettingScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Scenes
import CommonPresentation


// MARK: - OpenSourceLicenseViewController

final class OpenSourceLicenseViewController: UIHostingController<OpenSourceLicenseContainerView>, OpenSourceLicenseScene {
    
    private let viewModel: any OpenSourceLicenseViewModel
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any OpenSourceLicenseSceneInteractor)? { self.viewModel }
    
    init(
        viewModel: any OpenSourceLicenseViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = OpenSourceLicenseViewEventHandler()
        eventHandlers.onAppear = viewModel.prepare
        eventHandlers.selectLibrary = viewModel.selectLibrary(_:)
        eventHandlers.close = viewModel.close
        
        let containerView = OpenSourceLicenseContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
