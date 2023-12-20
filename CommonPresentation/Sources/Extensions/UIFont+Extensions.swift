//
//  UIFont+Extensions.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/06.
//

import UIKit
import SwiftUI


extension UIFont {
    
    public var asFont: Font {
        return Font(self as CTFont)
    }
}
