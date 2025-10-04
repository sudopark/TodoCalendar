//
//  CalendarPaperView.swift
//  CalendarScenes
//
//  Created by sudo.park on 5/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation

final class CalenarPaperViewEventHandelr: Observable {
    
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
        return PapgerView(
            monthView: monthView,
            eventListView: eventListView
        )
        .onAppear(perform: eventHandler.onAppear)
        .environment(viewAppearance)
        .environment(eventHandler)
    }
    
    struct PapgerView: View {
        
        private let monthView: MonthContainerView
        private let eventListView: DayEventListContainerView
        @Environment(ViewAppearance.self) private var appearance
        @Environment(CalenarPaperViewEventHandelr.self) private var eventHandler
        
        @State private var keyboardHeightObserver = KeyboardHeightObserver()
        
        init(
            monthView: MonthContainerView,
            eventListView: DayEventListContainerView
        ) {
            self.monthView = monthView
            self.eventListView = eventListView
        }
        
        var body: some View {
            ScrollView {
                VStack {
                    self.monthView
                    self.eventListView
                }
                .offset(y: -keyboardHeightObserver.showingKeyboardHeight)
            }
            .background(appearance.colorSet.bg0.asColor)
        }
    }
}
