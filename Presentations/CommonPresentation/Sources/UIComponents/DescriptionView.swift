//
//  DescriptionView.swift
//  CommonPresentation
//
//  Created by sudo.park on 9/18/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI


public struct DescriptionView: View {
    
    private let descriptions: [String]
    private let spacing: CGFloat
    @Environment(ViewAppearance.self) private var appearance
    
    public init(descriptions: [String], spacing: CGFloat = 4) {
        self.descriptions = descriptions
        self.spacing = spacing
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: self.spacing) {
            ForEach(self.descriptions, id: \.self) {
                self.tipView($0)
            }
        }
    }
    
    private func tipView(_ description: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("•")
            Text(description)
                .multilineTextAlignment(.leading)
        }
        .font(appearance.fontSet.subSubNormal.asFont)
        .foregroundStyle(appearance.colorSet.text2.asColor)
    }
}
