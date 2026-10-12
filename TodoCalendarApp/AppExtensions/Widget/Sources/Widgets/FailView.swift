//
//  FailView.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/26/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import WidgetKit
import Domain
import CommonPresentation
import Extensions
import WidgetScenes


struct FailView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) private var widgetFamily
    var colorSet: any ColorSet {
        return ColorSetKeys.systemTheme.convert(isSystemDarkTheme: colorScheme != .light)
    }
    
    private let errorModel: WidgetErrorModel
    init(errorModel: WidgetErrorModel) {
        self.errorModel = errorModel
    }
    
    var body: some View {
        if self.errorModel.isCustomStyleLocked {
            WidgetCustomStyleLockedView(family: self.widgetFamily)
                .widgetURL(WidgetStyleLicenseLink.url)
        } else {
            self.failMessageView
        }
    }

    private var failMessageView: some View {
        VStack(spacing: 8) {
            Text(errorModel.message)
                .font(.system(size: 14))
                .foregroundStyle(colorSet.text0.asColor)
            
            if let reason = errorModel.reason {
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(colorSet.text1.asColor)
            }
        }
    }
}


struct FailViewPreviewProvider: PreviewProvider {
    static var previews: some View {
        FailView(
            errorModel: .init(
                error: RuntimeError("raw error"),
                message: nil
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
        .containerBackground(.background , for: .widget)
    }
}
