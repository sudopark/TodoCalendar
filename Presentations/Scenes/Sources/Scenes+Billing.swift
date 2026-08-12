//
//  Scenes+Billing.swift
//  Scenes
//
//  Created by sudo.park on 8/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
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
    func makePaywallScene(closesAfterPurchase: Bool) -> any PaywallScene
}
