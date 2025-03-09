//
//  SelectDayDialogView.swift
//  CalendarScenes
//
//  Created by sudo.park on 3/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


final class SelectDayDialogViewState: ObservableObject {
    
    @Published fileprivate var selectDate: Date = Date()
    private var didBind = false
    
    func bind(_ viewModel: any SelectDayDialogViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true
        
        self.selectDate = viewModel.initialCurrentSelectDate
    }
}

final class SelectDayDialogEventHandler: ObservableObject {
    
    var daySelected: (Date) -> Void = { _ in }
    var confirmSelect: () -> Void = { }
    func bind(_ viewModel: any SelectDayDialogViewModel) {
        self.daySelected = viewModel.select(_:)
        self.confirmSelect = viewModel.confirmSelect
    }
}

struct SelectDayDialogContainerView: View {
    
    @StateObject private var state: SelectDayDialogViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: SelectDayDialogEventHandler
    
    var stateBinding: (SelectDayDialogViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandler: SelectDayDialogEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
    }
    
    var body: some View {
        return SelectDayDialogView()
            .onAppear {
                self.stateBinding(self.state)
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandler)
    }
}


private struct SelectDayDialogView: View {
    
    @EnvironmentObject private var state: SelectDayDialogViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandler: SelectDayDialogEventHandler
    
    var body: some View {
        BottomSlideView {
            
            VStack(alignment: .leading, spacing: 10) {
                
                DatePicker("", selection: $state.selectDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .onChange(of: state.selectDate, initial: false) { _, new in
                        self.eventHandler.daySelected(new)
                    }
                
                BottomConfirmButton(title: "calendar::move_date".localized())
                    .eventHandler(\.onTap) {
                        self.eventHandler.confirmSelect()
                    }
            }
        }
    }
}



// MARK: - preview

struct SelectDayDialogView_Preview: PreviewProvider {
    
    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let eventHandler = SelectDayDialogEventHandler()
        let state = SelectDayDialogViewState()
        let view = SelectDayDialogView()
            .environmentObject(state)
            .environmentObject(eventHandler)
            .environmentObject(viewAppearance)
        return view
    }
}
