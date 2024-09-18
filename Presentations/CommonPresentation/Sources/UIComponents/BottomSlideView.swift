//
//  BottomSlideView.swift
//  CommonPresentation
//
//  Created by sudo.park on 2/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI

public struct BottomSlideView<ContentView: View>: View {
    
    private let contentView: ContentView
    public var outsideTap: () -> Void = { }
    
    @EnvironmentObject private var appearance: ViewAppearance
    
    public init(_ contentView: () -> ContentView) {
        self.contentView = contentView()
    }
    
    public var body: some View {
        
        VStack {
            ZStack {
                Color.black.opacity(0.001).onTapGesture(perform: self.outsideTap)
                Spacer()
            }
            
            ZStack {
                self.contentView
            }
            .padding()
            .background(
                Rectangle()
                    .fill(appearance.colorSet.bg0.asColor)
                    .clipShape(.rect(
                        topLeadingRadius: 10, topTrailingRadius: 10
                    ))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}
