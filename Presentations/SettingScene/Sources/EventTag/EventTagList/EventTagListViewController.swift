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
        hasNavigation: Bool,
        viewModel: any EventTagListViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let containerView = EventTagListContainerView(
            hasNavigation: hasNavigation,
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel, viewAppearance) })
        .eventHandler(\.onAppear, viewModel.reload)
        .eventHandler(\.addTag, viewModel.addNewTag)
        .eventHandler(\.closeScene, viewModel.close)
        .eventHandler(\.toggleEventTagViewingIsOn, viewModel.toggleIsOn(_:))
        .eventHandler(\.showTagDetail, viewModel.showTagDetail(_:))
        .eventHandler(\.integrateService, viewModel.integrateCalendar(serviceId:))
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
