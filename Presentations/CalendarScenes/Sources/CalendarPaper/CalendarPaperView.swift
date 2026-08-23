//
//  CalendarPaperView.swift
//  CalendarScenes
//
//  Created by sudo.park on 5/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Extensions
import CommonPresentation

@Observable final class CalendarPaperViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    // 값 자체엔 의미가 없다 — 증가가 곧 스크롤 트리거다.
    fileprivate var scrollToVoiceInputTrigger: Int = 0

    func bind(_ viewModel: any CalendarPaperViewModel) {

        guard self.didBind == false else { return }
        self.didBind = true

        viewModel.requestScrollToVoiceInput
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scrollToVoiceInputTrigger += 1
            }
            .store(in: self.cancellables)
    }
}

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
    
    @State private var state: CalendarPaperViewState = .init()
    var stateBinding: (CalendarPaperViewState) -> Void = { _ in }

    var body: some View {
        return PapgerView(
            monthView: monthView,
            eventListView: eventListView
        )
        .onAppear {
            self.stateBinding(self.state)
            self.eventHandler.onAppear()
        }
        .environment(state)
        .environment(viewAppearance)
        .environment(eventHandler)
    }

    struct PapgerView: View {

        private let monthView: MonthContainerView
        private let eventListView: DayEventListContainerView
        @Environment(ViewAppearance.self) private var appearance
        @Environment(CalenarPaperViewEventHandelr.self) private var eventHandler
        @Environment(CalendarPaperViewState.self) private var state

        @State private var keyboardHeightObserver = KeyboardHeightObserver()

        init(
            monthView: MonthContainerView,
            eventListView: DayEventListContainerView
        ) {
            self.monthView = monthView
            self.eventListView = eventListView
        }

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        self.monthView
                        self.eventListView
                    }
                    .offset(y: -keyboardHeightObserver.showingKeyboardHeight)
                }
                .background(appearance.colorSet.bg0.asColor)
                .onChange(of: self.state.scrollToVoiceInputTrigger) { _, _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(DayEventListScrollAnchor.quickAddField, anchor: .bottom)
                    }
                }
            }
        }
    }
}
