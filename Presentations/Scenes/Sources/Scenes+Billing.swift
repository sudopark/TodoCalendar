//
//  Scenes+Billing.swift
//  Scenes
//

import UIKit
import Domain


// MARK: - PaywallScene Interactable & Listenable

public protocol PaywallSceneInteractor: AnyObject { }


// MARK: - PaywallScene

public protocol PaywallScene: Scene where Interactor == any PaywallSceneInteractor { }


// MARK: - Builder

public protocol PaywallSceneBuilder: AnyObject {

    @MainActor
    func makePaywallScene() -> any PaywallScene
}
