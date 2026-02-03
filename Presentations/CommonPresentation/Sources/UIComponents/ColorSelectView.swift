//
//  ColorSelectView.swift
//  CommonPresentation
//
//  Created by sudo.park on 2/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI


public struct ColorSelectView: View {
    
    @Environment(ViewAppearance.self) private var appearance
    @State private var selectedColor: Color
    
    public var colorSelected: (Color) -> Void = { _ in }
    
    public init(_ color: Color) {
        self._selectedColor = .init(initialValue: color)
    }
    
    private let gradientColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple
    ]
    
    public var body: some View {
        
        ZStack {
            
            Circle()
                .stroke(
                    .angularGradient(colors: gradientColors, center: .center, startAngle: .zero, endAngle: .radians(Double.pi * 2))
                )
                .foregroundStyle(.clear)
                .frame(width: 28, height: 28)
            
            Circle()
                .frame(width: 20, height: 20)
                .foregroundStyle(selectedColor)
        }
        .overlay {
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .opacity(0.15)
        }
        .onChange(of: selectedColor) { _, newColor in
            self.colorSelected(newColor)
        }
    }
}
