//
//  
//  SelectMapAppDialogView.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SelectMapAppDialogViewState

@Observable final class SelectMapAppDialogViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var supportMapApps: [SupportMapApps] = []
    var openMapWithThisSelection: Bool = false
    
    func bind(_ viewModel: any SelectMapAppDialogViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        self.supportMapApps = viewModel.supportMapApps
        
        viewModel.alwaysSelectThisMapOption
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] option in
                self?.openMapWithThisSelection = option
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - SelectMapAppDialogViewEventHandler

final class SelectMapAppDialogViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var selectMap: (SupportMapApps) -> Void = { _ in }
    var toggleOpenMapWithSelect: () -> Void = { }

    func bind(_ viewModel: any SelectMapAppDialogViewModel) {
        close = viewModel.close
        selectMap = viewModel.selectMap(_:)
        toggleOpenMapWithSelect = viewModel.toggleAlwaysSelectThisMap
    }
}


// MARK: - SelectMapAppDialogContainerView

struct SelectMapAppDialogContainerView: View {
    
    @State private var state: SelectMapAppDialogViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SelectMapAppDialogViewEventHandler
    
    var stateBinding: (SelectMapAppDialogViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SelectMapAppDialogViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SelectMapAppDialogView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
    }
}

// MARK: - SelectMapAppDialogView

struct SelectMapAppDialogView: View {
    
    @Environment(ViewAppearance.self) private var appearance
    @Environment(SelectMapAppDialogViewState.self) private var state
    @Environment(SelectMapAppDialogViewEventHandler.self) private var eventHandlers
    
    private let gridRow: [GridItem] = [
        .init(.flexible(minimum: 100, maximum: 200)),
        .init(.flexible(minimum: 100, maximum: 200))
    ]
    
    var body: some View {
        BottomSlideView(backgroundColor: appearance.colorSet.bg0.withAlphaComponent(0.9).asColor) {
            
            VStack(spacing: 16) {
                
                Text("eventDetail.place::select_map_app".localized())
                    .font(appearance.fontSet.subNormalWithBold.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                    .padding(.top, 12)
                
                LazyVGrid(columns: gridRow) {
                    ForEach(state.supportMapApps, id: \.self) { app in
                        mapAppView(app)
                    }
                }
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(appearance.colorSet.line.asColor)
                    .frame(height: 1)
                    .padding(.top, 20)
                
                toggleSelectThisMapView
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                ConfirmButton(
                    title: "common.close".localized(),
                    textColor: appearance.colorSet.secondaryBtnText.asColor,
                    backgroundColor: appearance.colorSet.secondaryBtnBackground.asColor
                )
                .eventHandler(\.onTap, eventHandlers.close)
            }
        }
    }
    
    private func mapAppView(_ app: SupportMapApps) -> some View {
        VStack {
            Image(app.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            
            Text(app.name)
                .foregroundStyle(appearance.colorSet.text0.asColor)
                .font(appearance.fontSet.normal.asFont)
        }
        .onTapGesture {
            eventHandlers.selectMap(app)
        }
    }
    
    private var toggleSelectThisMapView: some View {
        HStack {
            
            Image(
                systemName: state.openMapWithThisSelection
                ? "checkmark.square.fill" : "checkmark.square"
            )
            .font(appearance.fontSet.normal.asFont)
            .foregroundStyle(appearance.colorSet.text1.asColor)
            
            Text("eventDetail.place::always_select_this_map".localized())
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)
        }
        .onTapGesture {
            eventHandlers.toggleOpenMapWithSelect()
        }
    }
}


// MARK: - preview

struct SelectMapAppDialogViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendarSetting = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let setting = AppearanceSettings(
            calendar: calendarSetting,
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = SelectMapAppDialogViewState()
        let eventHandlers = SelectMapAppDialogViewEventHandler()
        
        state.supportMapApps = [
            .apple, .google
        ]
        
        let view = SelectMapAppDialogView()
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
        return view
    }
}

