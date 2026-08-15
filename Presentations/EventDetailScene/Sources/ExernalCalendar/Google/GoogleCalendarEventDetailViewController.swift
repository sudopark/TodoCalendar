//
//  
//  GoogleCalendarEventDetailViewController.swift
//  EventDetailScene
//
//  Created by sudo.park on 5/19/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import UIKit
import SwiftUI
import Combine
import Prelude
import Optics
import Scenes
import CommonPresentation


// MARK: - GoogleCalendarEventDetailViewController

final class GoogleCalendarEventDetailViewController: UIHostingController<GoogleCalendarEventDetailContainerView>, GoogleCalendarEventDetailScene {

    private let viewModel: any GoogleCalendarEventDetailViewModel
    let viewAppearance: ViewAppearance
    weak var router: (any GoogleCalendarEventDetailRouting)?

    @MainActor
    var interactor: (any GoogleCalendarEventDetailSceneInteractor)? { self.viewModel }

    private var hasChanges: Bool = false
    private var isSaving: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    init(
        viewModel: any GoogleCalendarEventDetailViewModel,
        viewAppearance: ViewAppearance
    ) {
        self.viewModel = viewModel
        self.viewAppearance = viewAppearance

        let eventHandlers = GoogleCalendarEventDetailViewEventHandler()
        eventHandlers.bind(viewModel)

        let containerView = GoogleCalendarEventDetailContainerView(
            viewAppearance: viewAppearance,
            eventHandlers: eventHandlers
        )
        .eventHandler(\.stateBinding, { $0.bind(viewModel) })

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


// MARK: - 스와이프 dismiss 시 변경사항 보호

extension GoogleCalendarEventDetailViewController: UIAdaptivePresentationControllerDelegate {

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
