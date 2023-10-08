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
        
        switch color {
        case .defaultLight:
            self.colorSet = DefaultLightColorSet()
        }
        
        switch font {
        case .systemDefault:
            self.fontSet = SystemDefaultFontSet()
        }
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
