//
//  LandmarkLabelView.swift
//  EventDetailScene
//
//  Created by sudo.park on 7/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// 상세 화면 2곳(EventDetail·DoneTodo)이 공유하는 장소 라벨(이름+주소+xmark 아이콘).
struct LandmarkLabelView: View {

    @Environment(ViewAppearance.self) private var appearance

    private let landmark: SelectedPlaceModel.LandmarkModel

    init(_ landmark: SelectedPlaceModel.LandmarkModel) {
        self.landmark = landmark
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(self.landmark.name)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                    .font(self.appearance.fontSet.size(14).asFont)

                if let address = self.landmark.address {
                    Text(address)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                        .font(self.appearance.fontSet.size(12).asFont)
                }
            }

            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
                .font(self.appearance.fontSet.size(14).asFont)
        }
    }
}
