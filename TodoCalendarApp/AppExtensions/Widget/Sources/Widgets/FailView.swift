//
//  FailView.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/26/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation

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
        Text(errorModel.message)
            .font(.system(size: 15))
            .foregroundStyle(colorSet.text0.asColor)
    }
}
