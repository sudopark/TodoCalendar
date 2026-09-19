//
//  WidgetStyleToggleFormView.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation


struct WidgetStyleToggleFormView<Item: WidgetStyleItem>: View {

    @Environment(ViewAppearance.self) private var appearance

    var title: String = "widget.style.edit::items::section".localized()
    let setting: Item.Setting
    let onChange: (any WidgetStyleSetting) -> Void

    var body: some View {
        Section {
            ForEach(Array(Item.allCases), id: \.self) { item in
                self.itemRow(item)
                    .listRowBackground(appearance.colorSet.bg1.asColor)
            }
        } header: {
            Text(self.title)
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
        }
    }

    private func itemRow(_ item: Item) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Metric.SpacingToken.xxsmall.value) {
                Text(item.name)
                    .font(appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)

                if let note = item.note {
                    Text(note)
                        .font(appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(appearance.colorSet.text2.asColor)
                }
            }

            Spacer()

            Toggle(
                "",
                isOn: .init(
                    get: { self.setting[keyPath: item.settingKeyPath] },
                    set: { self.onChange(self.setting |> item.settingKeyPath .~ $0) }
                )
            )
            .controlSize(.small)
            .labelsHidden()
        }
    }
}
