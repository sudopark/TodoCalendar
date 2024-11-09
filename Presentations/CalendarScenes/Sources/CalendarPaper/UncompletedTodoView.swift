//
//  UncompletedTodoView.swift
//  CalendarScenes
//
//  Created by sudo.park on 11/9/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation


struct UncompletedTodoView: View {
    
    private let viewModels: [TodoEventCellViewModel]
    @EnvironmentObject private var appearance: ViewAppearance
    
    var requestDoneTodo: (String) -> Void = { _ in }
    var requestCancelDoneTodo: (String) -> Void = { _ in }
    var requestShowDetail: (any EventCellViewModel) -> Void = { _ in }
    var handleMoreAction: (any EventCellViewModel, EventListMoreAction) -> Void = { _, _ in }
    var refreshList: () -> Void = { }
    
    init(_ viewModels: [TodoEventCellViewModel]) {
        self.viewModels = viewModels
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("calendar::uncompletedTodos:title".localized())
                    .font(
                        appearance.fontSet.size(22+appearance.eventTextAdditionalSize, weight: .semibold).asFont
                    )
                    .foregroundStyle(appearance.colorSet.text0.asColor)
                
                Spacer()
                
                Button {
                    self.refreshList()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            
            ForEach(self.viewModels, id: \.customCompareKey) { cvm in
                
                EventListCellView(cellViewModel: cvm, isUncompletedTodo: true)
                    .eventHandler(\.requestDoneTodo, self.requestDoneTodo)
                    .eventHandler(\.requestCancelDoneTodo, self.requestCancelDoneTodo)
                    .eventHandler(\.requestShowDetail, self.requestShowDetail)
                    .eventHandler(\.handleMoreAction, self.handleMoreAction)
                    .frame(height: 50)
                    .layoutPriority(1)
            }
        }
    }
}
