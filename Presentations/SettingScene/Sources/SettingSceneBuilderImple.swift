//
//  SettingSceneBuilderImple.swift
//  SettingScene
//
//  Created by sudo.park on 10/31/23.
//

import Foundation
import Domain
import Scenes
import CommonPresentation


public final class SettingSceneBuilderImple: SettingSceneBuiler {
    
    private let usecaseFactory: UsecaseFactory
    private let viewAppearance: ViewAppearance
    
    public init(
        usecaseFactory: UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension SettingSceneBuilderImple {
    
    @MainActor
    public func makeEventTagDetailScene(
        originalInfo: OriginalTagInfo?,
        listener: (any EventTagDetailSceneListener)?
    ) -> any EventTagDetailScene {
        
        let detailBuilder = EventTagDetailSceneBuilerImple(
            usecaseFactory: self.usecaseFactory, 
            viewAppearance: self.viewAppearance
        )
        return detailBuilder.makeEventTagDetailScene(
            originalInfo: originalInfo, listener: listener
        )
    }
    
    @MainActor
    public func makeEventTagListScene(
        hasNavigation: Bool,
        listener: (any EventTagListSceneListener)?
    ) -> any EventTagListScene {
        
        let listBuilder = EventTagListSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        return listBuilder.makeEventTagListScene(
            hasNavigation: hasNavigation, listener: listener
        )
    }
    
    @MainActor
    public func makeSettingItemListScene() -> any SettingItemListScene {
        
        let apperanceSceneBuilder = AppearanceSettingSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let countrySelectSceneBuilder = CountrySelectSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let holidayListSceneBuilder = HolidayListSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            countrySelectSceneBuilder: countrySelectSceneBuilder
        )
        
        let builder = SettingItemListSceneBuilerImple(
            viewAppearance: self.viewAppearance,
            appearanceSceneBuilder: apperanceSceneBuilder,
            holidayListSceneBuilder: holidayListSceneBuilder
        )
        return builder.makeSettingItemListScene()
    }
}