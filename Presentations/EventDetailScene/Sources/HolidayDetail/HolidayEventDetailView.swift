//
//  
//  HolidayEventDetailView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - HolidayEventDetailViewState

@Observable final class HolidayEventDetailViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    func bind(_ viewModel: any HolidayEventDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
    }
}

// MARK: - HolidayEventDetailViewEventHandler

final class HolidayEventDetailViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any HolidayEventDetailViewModel) {
        // TODO: bind handlers
    }
}


// MARK: - HolidayEventDetailContainerView

struct HolidayEventDetailContainerView: View {
    
    @State private var state: HolidayEventDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: HolidayEventDetailViewEventHandler
    
    var stateBinding: (HolidayEventDetailViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: HolidayEventDetailViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return HolidayEventDetailView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
    }
}

// MARK: - HolidayEventDetailView

struct HolidayEventDetailView: View {
    
    @Environment(ViewAppearance.self) private var appearance
    @Environment(HolidayEventDetailViewState.self) private var state
    @Environment(HolidayEventDetailViewEventHandler.self) private var eventHandlers
    
    var body: some View {
        ZStack {
            ScrollView {
             
                VStack(spacing: 25) {
                    Spacer(minLength: 5)
                    self.nameView
                }
            }
            
            VStack {
                Spacer()
                
                BottomConfirmButton(title: "Close")
            }
            
        }
        .background(appearance.colorSet.bg0.asColor)
    }
    
    private var nameView: some View {
        Text("holiday name")
    }
    
    private var dateView: some View {
        Text("holiday date")
    }
    
    private var countryInfoView: some View {
        Text("country info")
    }
}


// MARK: - preview

struct HolidayEventDetailViewPreviewProvider: PreviewProvider {

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
        let state = HolidayEventDetailViewState()
        let eventHandlers = HolidayEventDetailViewEventHandler()
        
        let view = HolidayEventDetailView()
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
        return view
    }
}

