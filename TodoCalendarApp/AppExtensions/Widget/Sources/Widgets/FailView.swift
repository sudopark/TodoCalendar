//
//  FailView.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/26/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import WidgetKit
import CommonPresentation
import Extensions


struct FailView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return colorScheme == .light ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
    
    private let errorModel: WidgetErrorModel
    init(errorModel: WidgetErrorModel) {
        self.errorModel = errorModel
    }
    
    var body: some View {
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
