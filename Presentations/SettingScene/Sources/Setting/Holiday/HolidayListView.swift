//
//  
//  HolidayListView.swift
//  SettingScene
//
//  Created by sudo.park on 11/26/23.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - HolidayListViewState

final class HolidayListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var countryName: String = ""
    @Published var holidays: [HolidayItemModel] = []
    @Published var isRefreshing = false
    
    func bind(_ viewModel: any HolidayListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.isRefresingHolidays
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isRefreshing in
                self?.isRefreshing = isRefreshing
            })
            .store(in: &self.cancellables)
        
        viewModel.currentCountryName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.countryName = name
            })
            .store(in: &self.cancellables)
        
        viewModel.currentYearHolidays
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] items in
                self?.holidays = items
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - HolidayListViewEventHandler

final class HolidayListViewEventHandler: ObservableObject {
    
    var onAppear: () -> Void = { }
    var refresh: () -> Void = { }
    var selectCountry: () -> Void = { }
    var close: () -> Void = { }
    
    func bind(_ viewModel: any HolidayListViewModel) {
        self.onAppear = viewModel.prepare
        self.selectCountry = viewModel.selectCountry
        self.refresh = viewModel.refresh
        self.close = viewModel.close
    }
}


// MARK: - HolidayListContainerView

struct HolidayListContainerView: View {
    
    @StateObject private var state: HolidayListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: HolidayListViewEventHandler
    
    var stateBinding: (HolidayListViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: HolidayListViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return HolidayListView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - HolidayListView

struct HolidayListView: View {
    
    @EnvironmentObject private var state: HolidayListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: HolidayListViewEventHandler
    
    var body: some View {
        NavigationStack {
            
            List {
                countrySelectSectionView
                    .listRowSeparator(.hidden)
                
                holidayListSectionView
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Holiday".localized())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        eventHandlers.close()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if state.isRefreshing {
                        LoadingCircleView(appearance.colorSet.accent.asColor, lineWidth: 1)
                            .frame(width: 20, height: 20)
                    } else {
                        Button {
                            self.eventHandlers.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }
    
    private var countrySelectSectionView: some View {

        VStack(alignment: .leading) {
            
            Text("Current Country".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
            HStack {
                Text(self.state.countryName)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(self.appearance.fontSet.size(8).asFont)
                    .foregroundStyle(self.appearance.colorSet.subNormalText.asColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.appearance.colorSet.eventList.asColor)
            )
            .onTapGesture {
                self.eventHandlers.selectCountry()
            }
        }
    }
    
    private var holidayListSectionView: some View {
        
        VStack(alignment: .leading) {
            Text("Holidays".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
            
            ForEach(self.state.holidays, id: \.compareKey) { item in
                
                HStack(spacing: 8) {
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(self.appearance.tagColors.holiday.asColor)
                        .frame(width: 4)
                        .padding(.vertical, 5)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .minimumScaleFactor(0.7)
                            .font(self.appearance.fontSet.size(16).asFont)
                            .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                        
                        Text(item.dateText)
                            .font(self.appearance.fontSet.size(12).asFont)
                            .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(self.appearance.colorSet.eventList.asColor)
                )
            }
        }
    }
}

private extension HolidayItemModel {
    
    var compareKey: String {
        return "\(self.dateText)_\(self.name)"
    }
}


// MARK: - preview

struct HolidayListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting)
        let state = HolidayListViewState()
        let eventHandlers = HolidayListViewEventHandler()
        eventHandlers.refresh = {
            state.isRefreshing = true
        }
        state.countryName = "대한민국"
        
        state.holidays = (0..<15).compactMap { int in
            let holiday = Holiday(dateString: "2023-01-\(int+1)", localName: "some: \(int)", name: "some: \(int)")
            return HolidayItemModel(holiday)
        }
        
        let view = HolidayListView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}

