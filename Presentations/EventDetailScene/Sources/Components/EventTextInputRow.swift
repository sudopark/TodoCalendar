//
//  EventTextInputRow.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// MARK: - EventTextInputRow

struct EventTextInputRow<Focus: Hashable>: View {

    @Environment(ViewAppearance.self) private var appearance

    let systemImageName: String
    @Binding var text: String
    let placeholder: String
    let focusValue: Focus
    @FocusState.Binding var focusState: Focus?
    var onChangeText: (String) -> Void = { _ in }

    var body: some View {
        HStack(spacing: Metric.Spacing.large) {
            Image(systemName: self.systemImageName)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)

            TextField(
                "",
                text: $text,
                prompt: Text(self.placeholder)
                    .foregroundStyle(appearance.colorSet.placeHolder.asColor)
            )
            .focused($focusState, equals: focusValue)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .foregroundStyle(appearance.colorSet.text0.asColor)
            .font(appearance.fontSet.size(14).asFont)
            .onChange(of: text) { _, new in
                onChangeText(new)
            }
            .onSubmit { focusState = nil }
        }
    }
}
