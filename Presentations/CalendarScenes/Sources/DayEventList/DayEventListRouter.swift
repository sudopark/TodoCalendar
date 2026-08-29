//
//
//  DayEventListRouter.swift
//  CalendarScenes
//
//  Created by sudo.park on 2023/08/28.
//
//

import UIKit
import Prelude
import Optics
import Domain
import Scenes
import Extensions
import CommonPresentation


// MARK: - Routing

protocol DayEventListRouting: Routing, Sendable {

    func routeToMakeNewEvent(_ withParams: MakeEventParams)
    // TODO: tempplate 관련해서 초기 파라미터 필요할 수 있음
    func routeToSelectTemplateForMakeEvent()
    func showDoneTodoList()
    func showSharePreview(range: Range<TimeInterval>)
    func routeToSignIn()
    func routeToAIKeyboardInput()
    func routeToImageSourceSelect(onCancel: @escaping @Sendable () -> Void)
    func routeToAIGuide()
}

// MARK: - Router

final class DayEventListRouter: BaseRouterImple, DayEventListRouting, @unchecked Sendable {

    private let eventDetailSceneBuilder: any EventDetailSceneBuilder
    private let eventListSceneBuilder: any EventListSceneBuiler
    private let memberSceneBuilder: any MemberSceneBuilder
    private let aiKeyboardInputSceneBuilder: any AIAgentKeyboardInputSceneBuilder
    private let aiImageCommandSceneBuilder: any AIAgentImageCommandSceneBuilder
    private let sharePreviewSceneBuilder: any SharePreviewSceneBuilder
    private let imagePicker: ImagePicker = .init()
    private let viewAppearance: ViewAppearance

    init(
        eventDetailSceneBuilder: any EventDetailSceneBuilder,
        eventListSceneBuilder: any EventListSceneBuiler,
        memberSceneBuilder: any MemberSceneBuilder,
        aiKeyboardInputSceneBuilder: any AIAgentKeyboardInputSceneBuilder,
        aiImageCommandSceneBuilder: any AIAgentImageCommandSceneBuilder,
        sharePreviewSceneBuilder: any SharePreviewSceneBuilder,
        viewAppearance: ViewAppearance
    ) {
        self.eventDetailSceneBuilder = eventDetailSceneBuilder
        self.eventListSceneBuilder = eventListSceneBuilder
        self.memberSceneBuilder = memberSceneBuilder
        self.aiKeyboardInputSceneBuilder = aiKeyboardInputSceneBuilder
        self.aiImageCommandSceneBuilder = aiImageCommandSceneBuilder
        self.sharePreviewSceneBuilder = sharePreviewSceneBuilder
        self.viewAppearance = viewAppearance
    }
}


extension DayEventListRouter {

    // TODO: router implememnts

    func routeToMakeNewEvent(_ withParams: MakeEventParams) {
        Task { @MainActor in

            let next = self.eventDetailSceneBuilder.makeNewEventScene(withParams)
            self.scene?.present(next, animated: true)
        }
    }

    func routeToSelectTemplateForMakeEvent() {
        // TODO: route to tempplate select scene
    }

    func showDoneTodoList() {
        Task { @MainActor in
            let next = self.eventListSceneBuilder.makeDoneTodoEventListScene()
            self.scene?.present(next, animated: true)
        }
    }

    func showSharePreview(range: Range<TimeInterval>) {
        Task { @MainActor in
            let next = self.sharePreviewSceneBuilder.makeSharePreviewScene(range: range, kind: .day)
            self.scene?.present(next, animated: true)
        }
    }

    func routeToSignIn() {
        Task { @MainActor in
            let next = self.memberSceneBuilder.makeSignInScene()
            self.showBottomSlide(next)
        }
    }

    func routeToAIKeyboardInput() {
        Task { @MainActor in
            let next = self.aiKeyboardInputSceneBuilder.makeKeyboardInputScene()
            self.showBottomSlide(next)
        }
    }

    func routeToImageSourceSelect(onCancel: @escaping @Sendable () -> Void) {
        Task { @MainActor in
            var form = ActionSheetForm()
            form.title = "aiAgent::image::sourceSelect::title".localized()
            form.actions = [
                .init("aiAgent::image::source::library".localized()) { [weak self] in
                    self?.routeToImagePick(source: .photoLibrary, onCancel: onCancel)
                }
            ]
            if ImagePickSource.camera.isAvailable {
                form.actions.append(
                    .init("aiAgent::image::source::camera".localized()) { [weak self] in
                        self?.routeToImagePick(source: .camera, onCancel: onCancel)
                    }
                )
            }
            form.actions.append(.init("common.cancel".localized(), style: .cancel) { onCancel() })
            self.showActionSheet(form)
        }
    }

    private func routeToImagePick(
        source: ImagePickSource,
        onCancel: @escaping @Sendable () -> Void
    ) {
        Task { @MainActor in
            guard !source.isAccessDenied else {
                self.showAccessDeniedGuide(onCancel: onCancel)
                return
            }
            let picker = self.imagePicker.makeViewController(source: source) { [weak self] data in
                guard let data else {
                    onCancel()
                    return
                }
                self?.routeToImageCommand(imageData: data)
            }
            self.scene?.present(picker, animated: true)
        }
    }

    private func showAccessDeniedGuide(onCancel: @escaping @Sendable () -> Void) {
        let info = ConfirmDialogInfo()
            |> \.title .~ "aiAgent::image::camera::denied::title".localized()
            |> \.message .~ "aiAgent::image::camera::denied::message".localized()
            |> \.confirmText .~ "common.go_to_settings".localized()
            |> \.confirmed .~ pure({ [weak self] in
                self?.openSystemSetting()
                onCancel()
            })
            |> \.canceled .~ pure({ onCancel() })
        self.showConfirm(dialog: info)
    }

    private func routeToImageCommand(imageData: Data) {
        Task { @MainActor in
            let next = self.aiImageCommandSceneBuilder.makeImageCommandScene(imageData: imageData)
            self.showBottomSlide(next)
        }
    }

    func routeToAIGuide() {
        self.showWebView(GuideLink.aiInputPath)
    }
}
