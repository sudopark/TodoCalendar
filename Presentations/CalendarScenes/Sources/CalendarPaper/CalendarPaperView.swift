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
    var expandMonthIfCollapsed: () -> Void = { }
    
    func bind(_ viewModel: any CalendarPaperViewModel) {
        self.onAppear = viewModel.prepare
        self.expandMonthIfCollapsed = viewModel.expandMonthIfCollapsed
    }
}

private enum Constant {
    static let scrollSpace: String = "calendarPaperScroll"
    static let pullToExpandDistance: CGFloat = 60
    static let listColumnWidth: CGFloat = 390
    static let columnDividerWidth: CGFloat = 0.5
}

private struct ScrollReleaseNotifyingBehavior: ScrollTargetBehavior {

    let onRelease: () -> Void

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        self.onRelease()
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
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        @State private var keyboardHeightObserver = KeyboardHeightObserver()

        init(
            monthView: MonthContainerView,
            eventListView: DayEventListContainerView
        ) {
            self.monthView = monthView
            self.eventListView = eventListView
        }

        @State private var didPullPastExpandDistance: Bool = false

        var body: some View {
            let layout = CalendarPaperColumnLayout(
                horizontal: self.horizontalSizeClass, vertical: self.verticalSizeClass
            )
            Group {
                switch layout {
                case .singleColumn:
                    self.singleColumnBody()
                case .twoColumns:
                    self.twoColumnsBody()
                }
            }
            .environment(\.calendarPaperColumnLayout, layout)
        }

        private func singleColumnBody() -> some View {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        self.monthView
                        self.eventListView
                    }
                    .overlay(alignment: .top) { self.pullDistanceProbe() }
                    .offset(y: -keyboardHeightObserver.showingKeyboardHeight)
                }
                .coordinateSpace(.named(Constant.scrollSpace))
                .scrollTargetBehavior(
                    ScrollReleaseNotifyingBehavior { self.expandMonthIfPulledEnough() }
                )
                .background(appearance.colorSet.bg0.asColor)
                .onChange(of: self.state.scrollToVoiceInputTrigger) { _, _ in
                    self.scrollToQuickAddField(proxy)
                }
            }
        }

        private func twoColumnsBody() -> some View {
            HStack(spacing: 0) {
                ScrollView {
                    self.monthView
                }

                Rectangle()
                    .fill(appearance.colorSet.line.asColor)
                    .frame(width: Constant.columnDividerWidth)

                ScrollViewReader { proxy in
                    ScrollView {
                        self.eventListView
                            .offset(y: -keyboardHeightObserver.showingKeyboardHeight)
                    }
                    .onChange(of: self.state.scrollToVoiceInputTrigger) { _, _ in
                        self.scrollToQuickAddField(proxy)
                    }
                }
                .frame(width: Constant.listColumnWidth)
            }
            .background(appearance.colorSet.bg0.asColor)
        }

        private func scrollToQuickAddField(_ proxy: ScrollViewProxy) {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(DayEventListScrollAnchor.quickAddField, anchor: .bottom)
            }
        }

        private func pullDistanceProbe() -> some View {
            GeometryReader { geometry in
                let distance = geometry.frame(in: .named(Constant.scrollSpace)).minY
                Color.clear
                    .onChange(of: distance) { _, newDistance in
                        guard newDistance > Constant.pullToExpandDistance else { return }
                        self.didPullPastExpandDistance = true
                    }
            }
            .frame(height: 0)
        }

        private func expandMonthIfPulledEnough() {
            guard self.didPullPastExpandDistance else { return }
            self.didPullPastExpandDistance = false
            self.eventHandler.expandMonthIfCollapsed()
        }
    }
}
