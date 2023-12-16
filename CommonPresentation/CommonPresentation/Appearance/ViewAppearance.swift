//
//  ViewAppearance.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import UIKit
import Combine
import Domain


public class ViewAppearance: ObservableObject {
    
    @Published public var tagColors: EventTagColorSet
    @Published public var colorSet: any ColorSet
    @Published public var fontSet: any FontSet
    @Published public var eventOnCalendarSetting: EventOnCalendarSetting
    @Published public var eventlist: EventListSetting
    
    public init(setting: AppearanceSettings) {
        
        self.tagColors = .init(
            holiday: UIColor.from(hex: setting.tagColorSetting.holiday) ?? .clear,
            defaultColor: UIColor.from(hex: setting.tagColorSetting.default) ?? .clear
        )
        self.colorSet = setting.colorSetKey.convert()
        self.fontSet = setting.fontSetKey.convert()
        self.eventOnCalendarSetting = setting.eventOnCalendar
        self.eventlist = setting.eventList
    }
}

extension ViewAppearance {
    
    public var didUpdated: AnyPublisher<(EventTagColorSet, any FontSet, any ColorSet), Never> {
        return Publishers.CombineLatest3(
            self.$tagColors,
            self.$fontSet,
            self.$colorSet
        )
        .eraseToAnyPublisher()
    }
}

extension ColorSetKeys {
    
    public func convert() -> any ColorSet {
        switch self {
        case .defaultLight: return DefaultLightColorSet()
        }
    }
}

extension FontSetKeys {
    
    public func convert() -> any FontSet {
        switch self {
        case .systemDefault: return SystemDefaultFontSet()
        }
    }
}
