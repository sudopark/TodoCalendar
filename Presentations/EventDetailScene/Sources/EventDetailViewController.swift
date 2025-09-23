//
//  
//  EventDetailViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//

import UIKit
import Prelude
import Optics
import SwiftUI
import Combine
import Scenes
import CommonPresentation


// MARK: - EventDetailViewController

final class EventDetailViewController: UIHostingController<EventDetailContainerView>, EventDetailScene {
    
    private let viewModel: any EventDetailViewModel
    private let inputViewModel: any EventDetailInputViewModel
    private let viewAppearance: ViewAppearance
    weak var router: (any EventDetailRouting)?
    
    private var isSaving: Bool = false
    private var hasChanges: Bool = false
    
    @MainActor
    var interactor: EmptyInteractor?
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        viewModel: any EventDetailViewModel,
        inputViewModel: any EventDetailInputViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.inputViewModel = inputViewModel
        self.viewAppearance = viewAppearance
        
        let eventHandler = EventDetailViewEventHandlers()
        let containerView = EventDetailContainerView(
            eventHandler: eventHandler,
            viewAppearance: viewAppearance
        )
        .eventHandler(\.stateBinding, { [weak eventHandler] state in
            eventHandler?.bind(viewModel, inputViewModel, with: state)
            state.bind(viewModel, inputViewModel)
        })
        
        super.init(rootView: containerView)
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupPresentation()
    }
}

extension EventDetailViewController: UIAdaptivePresentationControllerDelegate {
    
    private func setupPresentation() {
        self.presentationController?.delegate = self
        
        Publishers.CombineLatest(
            self.viewModel.hasChanges,
            self.viewModel.isSaving
        )
        .receive(on: RunLoop.main)
        .sink(receiveValue: { [weak self] hasChanges, isSaving in
            self?.hasChanges = hasChanges
            self?.isSaving = isSaving
            self?.isModalInPresentation = hasChanges || isSaving
        })
        .store(in: &self.cancellables)
    }
    
    func presentationControllerDidAttemptToDismiss(
        _ presentationController: UIPresentationController
    ) {
        
        if self.isSaving {
            self.router?.showToast("eventDetail:isSaving:toast:message".localized())
            return
        }
        
        if self.hasChanges {
            self.showHasChanges()
            return
        }
    }
    
    private func showHasChanges() {
        
        let confirmClose: () -> Void = { [weak self] in
            self?.router?.closeScene()
        }
        
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("common.info".localized())
            |> \.message .~ pure("eventDetail:hasChanges:confirm:message".localized())
            |> \.confirmText .~ "eventDetail:hasChanges:confirm:continue".localized()
            |> \.withCancel .~ true
            |> \.cancelText .~ "common.close".localized()
            |> \.canceled .~ confirmClose
        
        self.router?.showConfirm(dialog: info)
    }
}
