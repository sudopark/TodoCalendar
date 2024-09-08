//
//  ForemostEventGuideView.swift
//  EventDetailScene
//
//  Created by sudo.park on 9/8/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation

struct ForemostEventGuideView: View {
    
    private let appearance: ViewAppearance
    var onClose: () -> Void = { }
    init(appearance: ViewAppearance) {
        self.appearance = appearance
    }
    
    var body: some View {
        ForemostEventGuideContentView()
            .eventHandler(\.onClose, onClose)
            .environmentObject(appearance)
    }
}

private struct ForemostEventGuideContentView: View {
    
    @EnvironmentObject private var appearance: ViewAppearance
    var onClose: () -> Void = { }
    
    var body: some View {
        BottomSlideView {
            VStack(spacing: 16) {
                
                ScrollView(showsIndicators: false) {
                    
                    VStack(alignment: .leading, spacing: 20) {
                        
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(self.appearance.colorSet.accentWarn.asColor)
                            
                            Text("calendar::event::more_action::foremost_event:title".localized())
                        }
                        .font(appearance.fontSet.bigBold.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                        .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("eventDetail:foremost:guide:message1".localized())
                                Text("eventDetail:foremost:guide:supports:message".localized())
                            }
                            .font(appearance.fontSet.normal.asFont)
                            .foregroundStyle(appearance.colorSet.text1.asColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletView("eventDetail:foremost:guide:supports:todo".localized())
                                bulletView("eventDetail:foremost:guide:supports:notRepeating_schedule".localized())
                            }
                            .font(appearance.fontSet.normal.asFont)
                            .foregroundStyle(appearance.colorSet.text1.asColor)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(appearance.colorSet.bg0.asColor)
                }
                
                
                ConfirmButton(title: "common.close".localized())
                    .eventHandler(\.onTap, onClose)
            }
        }
    }
    
    private func bulletView(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("-")
            Text(text)
        }
    }
}
