//
//  View+Extension.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/11.
//

import SwiftUI

extension View {
    
    public func asAnyView() -> AnyView {
        return AnyView(self)
    }
}
