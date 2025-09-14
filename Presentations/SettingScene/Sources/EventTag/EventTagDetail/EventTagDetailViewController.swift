//
//  
//  EventTagDetailViewController.swift
//  SettingScene
//
//  Created by sudo.park on 2023/10/03.
//
//

import UIKit
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventTagDetailViewController

final class EventTagDetailViewController: UIHostingController<EventTagDetailContainerView>, EventTagDetailScene {
    
    private let viewModel: any EventTagDetailViewModel
    private let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any EventTagDetailSceneInteractor)? { self.viewModel }
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventTagDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandler = EventTagDetailEventHandler()
        eventHandler.bind(viewModel)
        
        let containerView = EventTagDetailContainerView(
            viewAppearance: viewAppearance,
            eventHandler: eventHandler
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.bindIsPresentation()
    }
    
    private func bindIsPresentation() {
        
        self.viewModel.isProcessing
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isProcessing in
                self?.isModalInPresentation = isProcessing
            })
            .store(in: &self.cancellables)
    }
}
