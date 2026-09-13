//
//  WidgetStyleEditViewController.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import Domain
import Extensions
import Scenes
import CommonPresentation


final class WidgetStyleEditViewController: UIHostingController<WidgetStyleEditContainerView>, WidgetStyleEditScene {
    
    private let viewModel: any WidgetStyleEditViewModel
    private let cancellables = CancelBag()
    let viewAppearance: ViewAppearance
    
    @MainActor
    var interactor: (any WidgetStyleEditSceneInteractor)? { self.viewModel }
    
    init(
        variant: WidgetVariant,
        setting: WidgetAppearanceSettings,
        viewModel: any WidgetStyleEditViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance
        
        let eventHandlers = WidgetStyleEditViewEventHandler()
        eventHandlers.bind(viewModel)
        
        let containerView = WidgetStyleEditContainerView(
            variant: variant,
            setting: setting,
            eventHandler: eventHandlers,
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 엣지 스와이프 팝은 화면의 닫기 경로를 거치지 않아, 막지 않으면 편집분이 안내 없이 사라진다.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.viewModel.hasAnyUnsavedEdit
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] hasChanges in
                self?.navigationController?
                    .interactivePopGestureRecognizer?.isEnabled = !hasChanges
            })
            .store(in: self.cancellables)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}
