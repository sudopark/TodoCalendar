//
//  ViewAppearance.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import Foundation


public class ViewAppearance: ObservableObject {
    
    @Published public var colorSet: ColorSet
    @Published public var fontSet: FontSet
    
    public init(color: ColorSetKeys, font: FontSetKeys) {
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
