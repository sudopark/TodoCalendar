//
//  ShareViewController.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers


final class ShareViewController: UIViewController {

    private let factory = ShareUsecaseFactory(base: AppExtensionBase())

    override func viewDidLoad() {
        super.viewDidLoad()

        let viewModel = ShareCommandViewModel(
            submitService: self.factory.makeSubmitService(),
            imageTextRecognizeService: self.factory.makeImageTextRecognizeService(),
            loadSharedItem: { [weak self] in await self?.loadSharedItem() ?? .text("") },
            onClose: { [weak self] in self?.close() }
        )
        self.attach(viewModel)
    }

    private func attach(_ viewModel: ShareCommandViewModel) {
        let eventHandlers = ShareCommandViewEventHandler()
        eventHandlers.bind(viewModel)
        var containerView = ShareCommandContainerView(
            viewAppearance: self.factory.makeViewAppearance(
                isSystemDarkTheme: self.traitCollection.userInterfaceStyle == .dark
            ),
            eventHandlers: eventHandlers
        )
        containerView.stateBinding = { $0.bind(viewModel) }

        let hosting = UIHostingController(rootView: containerView)
        self.addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    private func close() {
        self.extensionContext?.completeRequest(returningItems: nil)
    }
}


// MARK: - 공유 항목 읽기

// extensionContext는 UIViewController 자체의 프로퍼티다 (UIKit 제공).
// Info.plist의 NSExtensionPrincipalClass로 지정된 VC에 시스템이 채워주므로
// SLComposeServiceViewController 같은 전용 베이스를 상속할 필요가 없다.
extension ShareViewController {

    private func loadSharedItem() async -> SharedCommandItem {
        let items = (self.extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        for provider in providers {
            if let imageData = await self.loadImageData(from: provider) {
                return .image(imageData)
            }
        }
        for provider in providers {
            if let text = await self.loadText(from: provider) {
                return .text(text)
            }
        }
        return .text("")
    }

    private func loadImageData(from provider: NSItemProvider) async -> Data? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        else { return nil }

        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        let types: [UTType] = [.plainText, .url]
        for type in types where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            switch try? await provider.loadItem(forTypeIdentifier: type.identifier) {
            case let text as String: return text
            case let url as URL: return url.absoluteString
            default: continue
            }
        }
        return nil
    }
}
