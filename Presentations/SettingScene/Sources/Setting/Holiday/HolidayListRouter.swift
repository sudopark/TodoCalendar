//
//  
//  HolidayListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol HolidayListRouting: Routing, Sendable { 
    
    func routeToSelectCountry()
}

// MARK: - Router

final class HolidayListRouter: BaseRouterImple, HolidayListRouting, @unchecked Sendable { 
    
    private let countrySelectSceneBuilder: any CountrySelectSceneBuiler
    init(
        countrySelectSceneBuilder: any CountrySelectSceneBuiler
    ) {
        self.countrySelectSceneBuilder = countrySelectSceneBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.navigationController?.popViewController(animated: animate)
        }
    }
}


extension HolidayListRouter {
    
    private var currentScene: (any HolidayListScene)? {
        self.scene as? (any HolidayListScene)
    }
    
    // TODO: router implememnts
    func routeToSelectCountry() {
        Task { @MainActor in
            
            let next = self.countrySelectSceneBuilder.makeCountrySelectScene()
            self.currentScene?.navigationController?.pushViewController(next, animated: true)
        }
    }
}
