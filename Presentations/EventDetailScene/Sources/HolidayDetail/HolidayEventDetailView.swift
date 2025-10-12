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
    
    var name: String = ""
    var dateText: String = ""
    var countryModel: CountryModel?
    
    func bind(_ viewModel: any HolidayEventDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.holidayName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.name = name
            })
            .store(in: &self.cancellables)
        
        viewModel.dateText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.dateText = text
            })
            .store(in: &self.cancellables)
        
        viewModel.countryModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.countryModel = model
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - HolidayEventDetailViewEventHandler

final class HolidayEventDetailViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }

    func bind(_ viewModel: any HolidayEventDetailViewModel) {
        
        self.onAppear = viewModel.refresh
        self.close = viewModel.close
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
                    
                    VStack(spacing: 16) {
                        if let model = self.state.countryModel {
                            self.countryInfoView(model)
                        }
                        
                        self.dateView
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 12)
            
            VStack {
                Spacer()
                
                BottomConfirmButton(title: "Close")
            }
            
        }
        .background(appearance.colorSet.bg0.asColor)
    }
    
    private var nameView: some View {
        HStack {
            
            RoundedRectangle(cornerRadius: 3)
                .fill(appearance.tagColors.holiday.asColor)
                .frame(width: 6)
            
            Text(self.state.name)
                .font(appearance.fontSet.size(22, weight: .semibold).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Spacer()
        }
    }
    
    private var dateView: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            Text(self.state.dateText)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Spacer()
        }
    }
    
    private func countryInfoView(_ model: CountryModel) -> some View {
        HStack(spacing: 16) {
            
            RemoteImageView(model.thumbnailUrl)
                .resize()
                .scaledToFill()
                .frame(width: 16, height: 16)
            
            Text(model.name)
                .font(appearance.fontSet.normal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Spacer()
        }
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
        
        state.name = "삼일절"
        state.dateText = "2025년 3월 1일 금요일"
        state.countryModel = .init(
            thumbnailUrl: "https://flagcdn.com/w160/kr.jpg",
            name: "대한민국"
        )
        
        let view = HolidayEventDetailView()
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
        return view
    }
}

