//
//  NavigationBackButton.swift
//  CommonPresentation
//
//  Created by sudo.park on 12/3/23.
//

import SwiftUI
import Extensions


public struct NavigationBackButton: View {
    
    private let text: String
    private let tapHandler: () -> Void
    
    public init(
        text: String? = nil,
        tapHandler: @escaping () -> Void
    ) {
        self.text = text ?? R.String.commonBack
        self.tapHandler = tapHandler
    }
    
    public var body: some View {
        Button {
            self.tapHandler()
        } label: {
            HStack {
                Image(systemName: "chevron.backward")
                Text(self.text)
            }
        }
    }
}
