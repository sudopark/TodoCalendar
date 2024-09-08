//
//  TodoEventGuideView.swift
//  EventDetailScene
//
//  Created by sudo.park on 9/8/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation

struct TodoEventGuideView: View {
    
    private let appearance: ViewAppearance
    var onClose: () -> Void = { }
    init(appearance: ViewAppearance) {
        self.appearance = appearance
    }
    
    var body: some View {
        TodoEventGuideContentView()
            .eventHandler(\.onClose, onClose)
            .environmentObject(self.appearance)
    }
}


private struct TodoEventGuideContentView: View {
    
    @EnvironmentObject private var appearance: ViewAppearance
    var onClose: () -> Void = { }
    
    var body: some View {
        BottomSlideView {
            VStack(spacing: 16) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        HStack {
                            Image(systemName: "flag.fill")
                            Text("eventDetail.edit::todo::case".localized())
                        }
                        .font(appearance.fontSet.bigBold.asFont)
                        .foregroundStyle(appearance.colorSet.text1.asColor)
                        .padding(.top, 20)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("eventDetail:todo:guide:message1".localized())
                                Text("eventDetail:todo:guide:message2".localized())
                                Text("eventDetail:todo:guide:message3".localized())
                                
                                Text("eventDetail:todo:guide:process:message".localized())
                            }
                            .font(appearance.fontSet.normal.asFont)
                            .foregroundStyle(appearance.colorSet.text1.asColor)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletView("eventDetail:todo:guide:process:bullet1".localized())
                                bulletView("eventDetail:todo:guide:process:bullet2".localized())
                                bulletView("eventDetail:todo:guide:process:bullet3".localized())
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

struct TodoEventGuideViewPreviewProvider: PreviewProvider {
    
    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        return TodoEventGuideView(appearance: viewAppearance)
    }
}
