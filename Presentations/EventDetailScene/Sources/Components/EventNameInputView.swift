//
//  EventNameInputView.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// MARK: - EventNameInputView

struct EventNameInputView<Focus: Hashable, ColorBar: View>: View {

    @Environment(ViewAppearance.self) private var appearance

    @Binding var name: String
    let focusValue: Focus
    @FocusState.Binding var focusState: Focus?
    @ViewBuilder let colorBar: () -> ColorBar
    var onChangeName: (String) -> Void = { _ in }

    var body: some View {
        HStack(spacing: Metric.Spacing.regular) {
            self.colorBar()

            TextField(
                "",
                text: $name,
                prompt: Text("eventDetail.edit::add_new_name::placeholder".localized())
                    .foregroundStyle(appearance.colorSet.placeHolder.asColor)
            )
            .focused($focusState, equals: focusValue)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(appearance.fontSet.size(22, weight: .semibold).asFont)
            .foregroundStyle(appearance.colorSet.text0.asColor)
            .onChange(of: name) { _, new in
                onChangeName(new)
            }
            .onSubmit { focusState = nil }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
