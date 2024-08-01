//
//  ForemostEventView.swift
//  CalendarScenes
//
//  Created by sudo.park on 6/27/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Prelude
import Optics
import Domain
import CommonPresentation


struct ForemostEventView: View {
    
    private let viewModel: any EventCellViewModel
    @EnvironmentObject private var appearance: ViewAppearance
    
    var requestDoneTodo: (String) -> Void = { _ in }
    var requestCancelDoneTodo: (String) -> Void = { _ in }
    var requestShowDetail: (any EventCellViewModel) -> Void = { _ in }
    var handleMoreAction: (any EventCellViewModel, EventListMoreAction) -> Void = { _, _ in }
    
    init(viewModel: any EventCellViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            Text("Foremost Event".localized())
                .font(
                    appearance.fontSet.size(22+appearance.eventTextAdditionalSize, weight: .semibold).asFont
                )
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            EventListCellView(cellViewModel: viewModel)
                .eventHandler(\.requestDoneTodo, self.requestDoneTodo)
                .eventHandler(\.requestCancelDoneTodo, self.requestCancelDoneTodo)
                .eventHandler(\.requestShowDetail, self.requestShowDetail)
                .eventHandler(\.handleMoreAction, self.handleMoreAction)
                .frame(height: 50)
                .layoutPriority(1)
        }
    }
}


struct ForemostEventViewPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        let cvm = TodoEventCellViewModel(
            "current-todo1", name: "current todo 1"
        )
        |> \.tagColor .~ .default
        |> \.periodText .~ .singleText(.init(text: "Todo".localized()))
        let vm = cvm
    }
}
