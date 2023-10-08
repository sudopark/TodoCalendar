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
    
    public init(
        tagColorSetting: EventTagColorSetting,
        color: ColorSetKeys,
        font: FontSetKeys
    ) {
        
        self.tagColors = .init(
            holiday: UIColor.from(hex: tagColorSetting.holiday) ?? .clear,
            defaultColor: UIColor.from(hex: tagColorSetting.default) ?? .clear
        )
        
        self.colorSet = color.convert()
        self.fontSet = font.convert()
    }
}

extension ViewAppearance {
    
    public var didUpdated: AnyPublisher<(any FontSet, any ColorSet), Never> {
        return Publishers.CombineLatest(
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
