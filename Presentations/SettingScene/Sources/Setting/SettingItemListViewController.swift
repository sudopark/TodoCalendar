//
//  
//  SettingItemListViewController.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - SettingItemListViewController

final class SettingItemListViewController: UIHostingController<SettingItemListContainerView>, SettingItemListScene {
    
    private let viewModel: any SettingItemListViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any SettingItemListSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any SettingItemListViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = SettingItemListViewEventHandler()
        eventHandlers.selectItem = viewModel.selectItem(_:)
        eventHandlers.close = viewModel.close
        
        let containerView = SettingItemListContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
