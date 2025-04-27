//
//  
//  EventTagSelectView.swift
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


// MARK: - EventTagSelectViewState

final class EventTagSelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var cellViewModels: [BaseCalendarEventTagCellViewModel] = []
    @Published var selectedId: EventTagId?
    
    func bind(_ viewModel: any EventTagSelectViewModel) {
        
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

// MARK: - EventTagSelectViewEventHandler

final class EventTagSelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var selectTag: (EventTagId) -> Void = { _ in }
    var onClose: () -> Void = { }
}


// MARK: - EventTagSelectContainerView

struct EventTagSelectContainerView: View {
    
    @StateObject private var state: EventTagSelectViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: EventTagSelectViewEventHandler
    
    var stateBinding: (EventTagSelectViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: EventTagSelectViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return EventTagSelectView()
            .onAppear {
                self.stateBinding(self.state)
                eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - EventTagSelectView

struct EventTagSelectView: View {
    
    @EnvironmentObject private var state: EventTagSelectViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: EventTagSelectViewEventHandler
    
    var body: some View {
        NavigationStack {
            
            List {
                
                Text("eventTag.default::selection::explain".localized())
                    .font(appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.text2.asColor)
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.bg0.asColor)
                    .padding(.bottom, 16)
                
                ForEach(state.cellViewModels, id: \.compareKey) { cvm in
                    cellView(cvm)
                        .listRowSeparator(.hidden)
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
        }
            .id(appearance.navigationBarId)
    }
    
    private func cellView(_ cellViewModel: BaseCalendarEventTagCellViewModel) -> some View {
        HStack(spacing: 12) {
            
            Circle()
                .fill(appearance.color(cellViewModel.id).asColor)
                .frame(width: 8, height: 8)
            
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
        .padding(.vertical, 8)
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

struct EventTagSelectViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = EventTagSelectViewState()
        state.cellViewModels = (0..<20).map {
            BaseCalendarEventTagCellViewModel(
                CustomEventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "#ff0000")
            )
            |> \.isOn .~ ($0 % 2 == 0)
        }
        state.selectedId = .custom("id:3")
        
        let eventHandlers = EventTagSelectViewEventHandler()
        
        let view = EventTagSelectView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

