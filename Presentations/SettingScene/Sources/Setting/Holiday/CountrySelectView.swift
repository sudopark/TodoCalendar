//
//  
//  CountrySelectView.swift
//  SettingScene
//
//  Created by sudo.park on 12/1/23.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - CountrySelectViewState

@Observable final class CountrySelectViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    var countries: [HolidaySupportCountry] = []
    var selectedCountryCode: String? = nil
    var isSavable: Bool = false
    var isSaving: Bool = false
    
    func bind(_ viewModel: any CountrySelectViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.supportCountries
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] countries in
                self?.countries = countries
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedCountryCode
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] code in
                self?.selectedCountryCode = code
            })
            .store(in: &self.cancellables)
        
        viewModel.isSaving
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isSaving = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.isConfirmable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isSavable = flag
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - CountrySelectViewEventHandler

final class CountrySelectViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var select: (String) -> Void = { _ in }
    var confirm: () -> Void = { }
    var close: () -> Void = { }
}


// MARK: - CountrySelectContainerView

struct CountrySelectContainerView: View {
    
    @State private var state: CountrySelectViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: CountrySelectViewEventHandler
    
    var stateBinding: (CountrySelectViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: CountrySelectViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return CountrySelectView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - CountrySelectView

struct CountrySelectView: View {
    
    @Environment(CountrySelectViewState.self) private var state
    @Environment(CountrySelectViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    var body: some View {
        NavigationStack {
            
            List {
                ForEach(self.state.countries, id: \.code) { country in
                    countryView(country)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 5, leading: 20, bottom: 5, trailing: 20))
                .listRowBackground(appearance.colorSet.bg0.asColor)
            }
            .navigationTitle("setting.holiday.country.title".localized())
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .listStyle(.plain)
            .background(appearance.colorSet.bg0.asColor)
            .listRowSpacing(0)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        self.eventHandlers.close()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    confirmButton
                }
            }
        }
            .id(appearance.navigationBarId)
    }
    
    func countryView(_ country: HolidaySupportCountry) -> some View {
        
        HStack {
            Text(country.name)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            
            Spacer()
            
            if self.state.selectedCountryCode == country.code {
                Image(systemName: "checkmark")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.eventHandlers.select(country.code)
        }
    }
    
    private var confirmButton: some View {
        if self.state.isSaving {
            return LoadingCircleView(
                self.appearance.colorSet.accent.asColor,
                lineWidth: 2
            )
            .frame(width: 20, height: 20)
            .asAnyView()
            
        } else {
            return Button {
                self.eventHandlers.confirm()
            } label: {
                Text("common.confirm".localized())
            }
            .disabled(!self.state.isSavable)
            .asAnyView()
        }
    }
}


// MARK: - preview

struct CountrySelectViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = CountrySelectViewState()
        let eventHandlers = CountrySelectViewEventHandler()
        
        state.countries = (0..<20).map {
            return HolidaySupportCountry(regionCode: "region:\($0)", code: "code:\($0)", name: "name:\($0)")
        }
        state.selectedCountryCode = "code:3"
        state.isSavable = true
        state.isSaving = true
        
        let view = CountrySelectView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
        return view
    }
}

