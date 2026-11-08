//
//  BottomSlideView.swift
//  CommonPresentation
//
//  Created by sudo.park on 2/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI

private enum Constant {
    static let maxContentWidth: CGFloat = 580
}

public struct BottomSlideView<ContentView: View>: View {
    
    private let customBackgroundColor: Color?
    private let contentView: ContentView
    public var outsideTap: () -> Void = { }
    
    @Environment(ViewAppearance.self) private var appearance
    
    public init(
        backgroundColor: Color? = nil,
        _ contentView: () -> ContentView
    ) {
        self.customBackgroundColor = backgroundColor
        self.contentView = contentView()
    }
    
    public var body: some View {
        
        VStack {
            Color.clear
            
            ZStack {
                self.contentView
            }
            .padding()
            .background(
                Rectangle()
                    .fill(customBackgroundColor ?? appearance.colorSet.bg0.asColor)
                    .clipShape(.rect(
                        topLeadingRadius: 10, topTrailingRadius: 10
                    ))
                    .ignoresSafeArea(edges: .bottom)
            )
            .frame(maxWidth: Constant.maxContentWidth)
        }
        .background(
            Color.black.opacity(0.001)
                .onTapGesture(perform: self.outsideTap)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
