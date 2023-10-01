//
//  
//  EventTagListViewController.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventTagListViewController

final class EventTagListViewController: UIHostingController<EventTagListContainerView>, EventTagListScene {
    
    private let viewModel: any EventTagListViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventTagListSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventTagListViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = EventTagListContainerView(
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        .eventHandler(\.onAppear, viewModel.reload)
        .eventHandler(\.closeScene, viewModel.close)
        .eventHandler(\.toggleEventTagViewingIsOn, viewModel.toggleIsOn(_:))
        .eventHandler(\.showTagDetail, viewModel.showTagDetail(_:))
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
