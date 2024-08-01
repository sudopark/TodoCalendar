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

final class CountrySelectViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var countries: [HolidaySupportCountry] = []
    @Published var selectedCountryCode: String? = nil
    @Published var isSavable: Bool = false
    @Published var isSaving: Bool = false
    
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

final class CountrySelectViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var select: (String) -> Void = { _ in }
    var confirm: () -> Void = { }
    var close: () -> Void = { }
}


// MARK: - CountrySelectContainerView

struct CountrySelectContainerView: View {
    
    @StateObject private var state: CountrySelectViewState = .init()
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
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - CountrySelectView

struct CountrySelectView: View {
    
    @EnvironmentObject private var state: CountrySelectViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: CountrySelectViewEventHandler
    
    var body: some View {
        NavigationStack {
            
            List {
                ForEach(self.state.countries, id: \.code) { country in
                    countryView(country)
                }
                .listRowSeparator(.hidden)
                
            }
            .navigationTitle("Country".localized())
            .listStyle(.plain)
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
                    .foregroundStyle(self.appearance.colorSet.accent.asColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
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
                Text("Confirm".localized())
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
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = CountrySelectViewState()
        let eventHandlers = CountrySelectViewEventHandler()
        
        state.countries = (0..<20).map {
            return HolidaySupportCountry(code: "code:\($0)", name: "name:\($0)")
        }
        state.selectedCountryCode = "code:3"
        state.isSavable = true
        state.isSaving = true
        
        let view = CountrySelectView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

