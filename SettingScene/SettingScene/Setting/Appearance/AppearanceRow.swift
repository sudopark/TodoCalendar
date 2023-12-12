//
//  AppearanceRow.swift
//  SettingScene
//
//  Created by sudo.park on 12/13/23.
//

import SwiftUI
import CommonPresentation


struct AppearanceRow< Content: View>: View {
    
    private let title: String
    private let subTitle: String?
    private let content: Content
    @EnvironmentObject private var appearance: ViewAppearance
    
    init(_ title: String, subTitle: String? = nil, _ content: Content) {
        self.title = title
        self.subTitle = subTitle
        self.content = content
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.normalText.asColor)
                
                if let subTitle {
                    Text(subTitle)
                        .font(self.appearance.fontSet.size(10).asFont)
                        .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                }
            }
            
            Spacer()
            
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(UIColor.systemGroupedBackground.asColor)
        )
    }
}

