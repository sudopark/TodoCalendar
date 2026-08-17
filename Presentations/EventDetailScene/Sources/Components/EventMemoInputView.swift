//
//  EventMemoInputView.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// MARK: - EventMemoInputView

struct EventMemoInputView<Focus: Hashable>: View {

    @Environment(ViewAppearance.self) private var appearance

    @Binding var memo: String
    let placeholder: String
    let focusValue: Focus
    @FocusState.Binding var focusState: Focus?
    var onChangeMemo: (String) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: Metric.Spacing.large) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)
                .padding(.top, spacing: .small)

            ZStack(alignment: .topLeading) {

                if memo.isEmpty {
                    Text(self.placeholder)
                        .foregroundStyle(appearance.colorSet.placeHolder.asColor)
                        .font(appearance.fontSet.size(14).asFont)
                        .padding(.leading, spacing: .xsmall)
                        .padding(.top, spacing: .regular)
                }

                TextEditor(text: $memo)
                    .focused($focusState, equals: focusValue)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                    .font(appearance.fontSet.size(14).asFont)
                    .textInputAutocapitalization(.never)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .onChange(of: memo) { _, new in
                        onChangeMemo(new)
                    }
            }
        }
    }
}
