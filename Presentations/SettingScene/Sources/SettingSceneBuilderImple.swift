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
    
    private let appId: String
    private let supportExternalCalendarServices: [any ExternalCalendarService]
    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance
    private let memberSceneBuilder: any MemberSceneBuilder
    
    public init(
        appId: String,
        supportExternalCalendarServices: [any ExternalCalendarService],
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance,
        memberSceneBuilder: any MemberSceneBuilder
    ) {
        self.appId = appId
        self.supportExternalCalendarServices = supportExternalCalendarServices
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
        self.memberSceneBuilder = memberSceneBuilder
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
        isRootNavigation: Bool,
        listener: (any EventTagListSceneListener)?
    ) -> any EventTagListScene {
        
        let settingSceneBuilder = self.eventSettingSceneBuilder()
        let detailSceneBuilder = EventTagDetailSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let listBuilder = EventTagListSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            settingSceneBuilder: settingSceneBuilder,
            tagDetailSceneBuilder: detailSceneBuilder
        )
        return listBuilder.makeEventTagListScene(
            isRootNavigation: isRootNavigation, listener: listener
        )
    }
    
    @MainActor
    public func makeSettingItemListScene() -> any SettingItemListScene {
        
        let colorThemeSelectSceneBuilder = ColorThemeSelectSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let timeZoneSelectSceneBuilder = TimeZoneSelectSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let apperanceSceneBuilder = AppearanceSettingSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            colorThemeSelectSceneBuiler: colorThemeSelectSceneBuilder,
            timeZoneSelectSceneBuilder: timeZoneSelectSceneBuilder
        )
        
        let eventSettingSceneBuilder = self.eventSettingSceneBuilder()
        
        let countrySelectSceneBuilder = CountrySelectSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let holidayListSceneBuilder = HolidayListSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            countrySelectSceneBuilder: countrySelectSceneBuilder
        )
        
        let feedbackSceneBuilder = FeedbackPostSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let builder = SettingItemListSceneBuilerImple(
            appId: self.appId,
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            appearanceSceneBuilder: apperanceSceneBuilder,
            eventSettingSceneBuilder: eventSettingSceneBuilder,
            holidayListSceneBuilder: holidayListSceneBuilder,
            memberSceneBuilder: self.memberSceneBuilder,
            feedbackPostSceneBuiler: feedbackSceneBuilder
        )
        return builder.makeSettingItemListScene()
    }
    
    private func eventSettingSceneBuilder() -> EventSettingSceneBuilerImple {
        let eventTagSelectSceneBuilder = EventTagSelectSceneBuilerImple(
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let eventNotificationDefaultTimeOptionSceneBuilder = EventNotificationDefaultTimeOptionSceneBuilerImple(
            usecaesFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance
        )
        
        let eventSettingSceneBuilder = EventSettingSceneBuilerImple(
            supportExternalCalendarServices: self.supportExternalCalendarServices,
            usecaseFactory: self.usecaseFactory,
            viewAppearance: self.viewAppearance,
            eventTagSelectSceneBuilder: eventTagSelectSceneBuilder,
            eventDefaultNotificationTimeSceneBuilder: eventNotificationDefaultTimeOptionSceneBuilder
        )
        return eventSettingSceneBuilder
    }
}
