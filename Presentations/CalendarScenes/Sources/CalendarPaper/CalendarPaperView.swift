//
//  CalendarPaperView.swift
//  CalendarScenes
//
//  Created by sudo.park on 5/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation

final class CalenarPaperViewEventHandelr: ObservableObject {
    
    var onAppear: () -> Void = { }
    
    func bind(_ viewModel: any CalendarPaperViewModel) {
        self.onAppear = viewModel.prepare
    }
}

struct CalenarPaperContainerView: View {
    
    private let viewAppearance: ViewAppearance
    private let monthView: MonthContainerView
    private let eventListView: DayEventListContainerView
    private let eventHandler: CalenarPaperViewEventHandelr
    
    @StateObject private var keyboardHeightObserver = KeyboardHeightObserver()
    
    init(
        monthView: MonthContainerView,
        eventListView: DayEventListContainerView,
        viewAppearance: ViewAppearance,
        eventHandler: CalenarPaperViewEventHandelr
    ) {
        self.monthView = monthView
        self.eventListView = eventListView
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
    }
    
    var body: some View {
        ScrollView {
            VStack {
                self.monthView
                self.eventListView
            }
            .offset(y: -keyboardHeightObserver.showingKeyboardHeight)
        }
        .onAppear(perform: eventHandler.onAppear)
    }
}
