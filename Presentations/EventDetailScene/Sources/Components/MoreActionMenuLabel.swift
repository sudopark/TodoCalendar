//
//  MoreActionMenuLabel.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// MARK: - MoreActionMenuLabel

struct MoreActionMenuLabel: View {

    @Environment(ViewAppearance.self) private var appearance

    var body: some View {
        Image(systemName: "ellipsis")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(self.appearance.colorSet.text0.asColor)
            .frame(width: 20, height: 20)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: Metric.Radius.regular)
                    .fill(self.appearance.colorSet.secondaryBtnBackground.asColor)
            }
    }
}
