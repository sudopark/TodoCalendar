//
//  CloseButton.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/30/23.
//

import SwiftUI


public struct CloseButton: View {
    
    @EnvironmentObject private var appearance: ViewAppearance
    public var onTap: () -> Void = { }
    
    public init() { }
    
    public var body: some View {
        
        Button {
            self.onTap()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    self.appearance.colorSet.event.asColor,
                    self.appearance.colorSet.eventList.asColor
                )
                .font(.system(size: 20))
        }
    }
}
