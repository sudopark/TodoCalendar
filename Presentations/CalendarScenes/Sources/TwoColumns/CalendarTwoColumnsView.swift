//
//  CalendarTwoColumnsView.swift
//  CalendarScenes
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Extensions
import CommonPresentation


@Observable final class CalendarTwoColumnsListViewState {

    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()

    // 값 자체엔 의미가 없다 — 증가가 곧 스크롤 트리거다.
    fileprivate var scrollToVoiceInputTrigger: Int = 0

    func bind(_ viewModel: any CalendarTwoColumnsViewModel) {

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


// MARK: - CalendarTwoColumnsListContainerView

struct CalendarTwoColumnsListContainerView: View {

    private let viewAppearance: ViewAppearance
    private let eventListView: DayEventListContainerView
    private let nextDayEventListView: NextDayEventListContainerView

    init(
        eventListView: DayEventListContainerView,
        nextDayEventListView: NextDayEventListContainerView,
        viewAppearance: ViewAppearance
    ) {
        self.eventListView = eventListView
        self.nextDayEventListView = nextDayEventListView
        self.viewAppearance = viewAppearance
    }

    @State private var state: CalendarTwoColumnsListViewState = .init()
    var stateBinding: (CalendarTwoColumnsListViewState) -> Void = { _ in }

    var body: some View {
        return CalendarTwoColumnsListView(
            eventListView: self.eventListView,
            nextDayEventListView: self.nextDayEventListView
        )
        .onAppear {
            self.stateBinding(self.state)
        }
        .environment(state)
        .environment(viewAppearance)
    }
}


// MARK: - CalendarTwoColumnsListView

struct CalendarTwoColumnsListView: View {

    private let eventListView: DayEventListContainerView
    private let nextDayEventListView: NextDayEventListContainerView
    @Environment(ViewAppearance.self) private var appearance
    @Environment(CalendarTwoColumnsListViewState.self) private var state

    init(
        eventListView: DayEventListContainerView,
        nextDayEventListView: NextDayEventListContainerView
    ) {
        self.eventListView = eventListView
        self.nextDayEventListView = nextDayEventListView
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack {
                    self.eventListView
                    self.nextDayEventListView
                }
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
