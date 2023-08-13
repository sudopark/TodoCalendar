//
//  View+Extension.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/11.
//

import SwiftUI
import Prelude
import Optics

extension View {
    
    public func asAnyView() -> AnyView {
        return AnyView(self)
    }
    
    public func eventHandler<Handler>(
        _ keyPath: WritableKeyPath<Self, Handler>,
        _ handler: Handler
    ) -> Self {
        return self |> keyPath .~ handler
    }
}
