//
//  
//  EventDefaultTagSelectView.swift
//  SettingScene
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation


// MARK: - EventDefaultTagSelectViewState

@Observable final class EventDefaultTagSelectViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    var cellViewModels: [BaseCalendarEventTagCellViewModel] = []
    var selectedId: EventTagId?
    
    func bind(_ viewModel: any EventDefaultTagSelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.cellViewModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] cvms in
                self?.cellViewModels = cvms
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedId
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] id in
                self?.selectedId = id
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - EventDefaultTagSelectViewEventHandler

final class EventDefaultTagSelectViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var selectTag: (EventTagId) -> Void = { _ in }
    var onClose: () -> Void = { }
    
    func bind(_ viewModel: any EventDefaultTagSelectViewModel) {
        self.onAppear = viewModel.loadList
        self.selectTag = viewModel.select(_:)
        self.onClose = viewModel.close
    }
}


// MARK: - EventDefaultTagSelectContainerView

struct EventDefaultTagSelectContainerView: View {
    
    @State private var state: EventDefaultTagSelectViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventDefaultTagSelectViewEventHandler
    
    var stateBinding: (EventDefaultTagSelectViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: EventDefaultTagSelectViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventDefaultTagSelectView()
            .onAppear {
                self.stateBinding(self.state)
                eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - EventDefaultTagSelectView

struct EventDefaultTagSelectView: View {
    
    @Environment(EventDefaultTagSelectViewState.self) private var state
    @Environment(EventDefaultTagSelectViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    var body: some View {
        NavigationStack {
            
            List {
                
                Text("eventTag.default::selection::explain".localized())
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.text2.asColor)
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.bg0.asColor)
                    .padding(.bottom, 16)
                
                ForEach(state.cellViewModels) { cvm in
                    cellView(cvm)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                        .listRowBackground(appearance.colorSet.bg0.asColor)
                }
            }
            .listStyle(.plain)
            .background(appearance.colorSet.bg0.asColor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton(tapHandler: eventHandlers.onClose)
                }
            }
            .navigationTitle("eventTag.default::title".localized())
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
        }
            .id(appearance.navigationBarId)
    }
    
    private func cellView(_ cellViewModel: BaseCalendarEventTagCellViewModel) -> some View {
        HStack(spacing: 12) {
            
            EventTagColorView(cellViewModel.id) { color in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            
            Text(cellViewModel.name)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(
                    cellViewModel.isOn
                    ? appearance.colorSet.text0.asColor
                    : appearance.colorSet.text2.asColor
                )
                .lineLimit(1)
            
            Spacer()
            
            if cellViewModel.id == state.selectedId {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.appearance.impactIfNeed()
            eventHandlers.selectTag(cellViewModel.id)
        }
    }
}


// MARK: - preview

struct EventDefaultTagSelectViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = EventDefaultTagSelectViewState()
        state.cellViewModels = (0..<20).map {
            BaseCalendarEventTagCellViewModel(
                CustomEventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "#ff0000")
            )
            |> \.isOn .~ ($0 % 2 == 0)
        }
        state.selectedId = .custom("id:3")
        
        let eventHandlers = EventDefaultTagSelectViewEventHandler()
        
        let view = EventDefaultTagSelectView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
        return view
    }
}

