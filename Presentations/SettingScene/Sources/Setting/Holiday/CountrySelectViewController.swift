//
//  
//  CountrySelectViewController.swift
//  SettingScene
//
//  Created by sudo.park on 12/1/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - CountrySelectViewController

final class CountrySelectViewController: UIHostingController<CountrySelectContainerView>, CountrySelectScene {
    
    private let viewModel: any CountrySelectViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any CountrySelectSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any CountrySelectViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = CountrySelectViewEventHandler()
        eventHandlers.onAppear = viewModel.prepare
        eventHandlers.select = viewModel.selectCountry(_:)
        eventHandlers.confirm = viewModel.confirm
        eventHandlers.close = viewModel.close
        
        let containerView = CountrySelectContainerView(
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
