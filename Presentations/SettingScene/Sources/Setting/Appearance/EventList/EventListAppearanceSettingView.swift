//
//  EventListAppearanceSettingView.swift
//  SettingScene
//
//  Created by sudo.park on 12/23/23.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


final class EventListAppearanceSettingViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var sampleModel: EventListAppearanceSampleModel?
    @Published var additionalFontSizeModel: EventTextAdditionalSizeModel = .init(0)
    @Published var showHolidayName: Bool = false
    @Published var showLunarCalendarDate: Bool = false
    @Published var is24hourTimeForm: Bool = false
    @Published var showUncompletedTodos: Bool = true
    
    init(_ setting: EventListAppearanceSetting) {
        self.additionalFontSizeModel = .init(setting.eventTextAdditionalSize)
        self.showHolidayName = setting.showHoliday
        self.showLunarCalendarDate = setting.showLunarCalendarDate
        self.is24hourTimeForm = setting.is24hourForm
        self.showUncompletedTodos = setting.showUncompletedTodos
    }
    
    func bind(_ viewModel: any EventListAppearnaceSettingViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.eventListSamepleModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.sampleModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.eventFontIncreasedSizeModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.additionalFontSizeModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.isShowHolidayName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.showHolidayName = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.isShowLunarCalendarDate
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.showLunarCalendarDate = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.isShowTimeWith24HourForm
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.is24hourTimeForm = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.showUncompletedTodo
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] show in
                self?.showUncompletedTodos = show
            })
            .store(in: &self.cancellables)
    }
}


final class EventListAppearanceSettingViewEventHandler: ObservableObject {
    
    var onAppear: () -> Void = { }
    var increaseFontSize: () -> Void = { }
    var decreaseFontSize: () -> Void = { }
    var toggleIsShowHolidayName: (Bool) -> Void = { _ in }
    var toggleShowLunarCalendarDate: (Bool) -> Void = { _ in }
    var toggleIs24HourFom: (Bool) -> Void = { _ in }
    var toggleShowUncompletedTodo: (Bool) -> Void = { _ in }
}


struct EventListAppearanceSettingView: View {
    
    @StateObject private var state: EventListAppearanceSettingViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandler: EventListAppearanceSettingViewEventHandler
    
    var stateBinding: (EventListAppearanceSettingViewState) -> Void = { _ in }
    
    init(_ setting: EventListAppearanceSetting) {
        self._state = .init(wrappedValue: .init(setting))
    }
    
    var body: some View {
        VStack {
            
            eventListSampleView
                .padding(.bottom, 12)
            
            AppearanceRow("setting.appearance.event.fontSize".localized(), fontSizeSettingView)
            
            AppearanceRow("setting.appearance.event.show_holidayName".localized(), showHolidayNameView)
                .onReceive(state.$showHolidayName, perform: eventHandler.toggleIsShowHolidayName)
            
            AppearanceRow("setting.appearance.event.show_lunar".localized(), showLunarCalendarView)
                .onReceive(state.$showLunarCalendarDate, perform: eventHandler.toggleShowLunarCalendarDate)
            
            AppearanceRow("setting.appearance.event._24form".localized(), is24HourFormView)
                .onReceive(state.$is24hourTimeForm, perform: eventHandler.toggleIs24HourFom)
            
            AppearanceRow("setting.appearance.event.sample::uncompleted_todo::toggle".localized(), showUncompletedTodoView)
                .onReceive(state.$showUncompletedTodos, perform: eventHandler.toggleShowUncompletedTodo)
            
        }
        .padding(.top, 20)
        .onAppear {
            self.stateBinding(self.state)
            self.eventHandler.onAppear()
        }
    }
    
    private var eventListSampleView: some View {
        VStack(alignment: .leading, spacing: 6) {
            
            VStack(alignment: .leading) {
                
                if let holidayName = state.sampleModel?.holidayName {
                    Text(holidayName)
                        .font(appearance.eventSubNormalTextFontOnList().asFont)
                        .foregroundStyle(Color.red)
                }
             
                HStack {
                    Text(state.sampleModel?.dateText ?? "")
                        .font(
                            self.appearance.fontSet.size(22+appearance.eventTextAdditionalSize, weight: .semibold).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.text0.asColor)
                        .padding(.bottom, 3)
                    
                    if let lunarDate = state.sampleModel?.lunarDateText {
                        Text(lunarDate)
                            .font(
                                self.appearance.fontSet.size(20+appearance.eventTextAdditionalSize, weight: .semibold).asFont
                            )
                            .foregroundColor(self.appearance.colorSet.text2.asColor)
                            .padding(.bottom, 3)
                    }
                    
                    Spacer()
                }
            }
            
            HStack(spacing: 8) {
                eventSampleTimeView
                .frame(width: 52)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(appearance.tagColors.defaultColor.asColor)
                    .frame(width: 6)
                    .frame(maxHeight: 50)
                
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("setting.appearance.event.sample::name".localized())
                            .minimumScaleFactor(0.7)
                            .font(self.appearance.eventTextFontOnList().asFont)
                            .foregroundColor(self.appearance.colorSet.text0.asColor)
                        
                        Text("setting.appearance.event.sample::description".localized())
                            .minimumScaleFactor(0.7)
                            .font(self.appearance.fontSet.size(13+appearance.eventTextAdditionalSize).asFont)
                            .foregroundColor(self.appearance.colorSet.text1.asColor)
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 4).padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(appearance.colorSet.bg1.asColor)
            )
        }
    }
    
    private var eventSampleTimeView: some View {
        
        func timeView(_ text: String) -> some View {
            Text(text)
                .minimumScaleFactor(0.7)
                .font(
                    self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont
                )
                .foregroundColor(self.appearance.colorSet.text0.asColor)
        }
        
        let pmView: some View = {
            Text("PM")
                .minimumScaleFactor(0.7)
                .font(appearance.fontSet.size(9+appearance.eventTextAdditionalSize).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
        }()
        
        return VStack(alignment: .center, spacing: 2) {
            if state.sampleModel?.is24HourForm == true {
                timeView("13:00")
                timeView("14:00")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    timeView("1:00")
                    pmView
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    timeView("2:00")
                    
                    pmView
                }
            }
        }
    }
    
    private var fontSizeSettingView: some View {
        HStack(spacing: 8) {
            
            Text(state.additionalFontSizeModel.sizeText)
                .font(appearance.fontSet.size(12).asFont)
                .foregroundStyle(appearance.colorSet.text2.asColor)
            
            HStack(spacing: 2) {
                
                Button {
                    eventHandler.decreaseFontSize()
                } label: {
                    Text("-")
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                        .padding(.vertical, 2)
                        .padding(.leading, 8).padding(.trailing, 2)
                }
                .disabled(!state.additionalFontSizeModel.isDescreasable)
                
                Divider()
                    .frame(height: 12)
                
                Button {
                    eventHandler.increaseFontSize()
                } label: {
                    Text("+")
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.text0.asColor)
                        .padding(.vertical, 2)
                        .padding(.leading, 2).padding(.trailing, 8)
                }
                .disabled(!state.additionalFontSizeModel.isIncreasable)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(appearance.colorSet.dayBackground.asColor)
            )
        }
    }
    
    private var showHolidayNameView: some View {
        Toggle("", isOn: $state.showHolidayName)
            .labelsHidden()
    }
    
    private var showLunarCalendarView: some View {
        Toggle("", isOn: $state.showLunarCalendarDate)
            .labelsHidden()
    }
    
    private var is24HourFormView: some View {
        Toggle("", isOn: $state.is24hourTimeForm)
            .labelsHidden()
    }
    
    private var showUncompletedTodoView: some View {
        Toggle("", isOn: $state.showUncompletedTodos)
            .labelsHidden()
    }
}


// MARK: - preview

struct EventListAppearanceSettingPreviewProvider: PreviewProvider {
    
    
    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let handler = EventListAppearanceSettingViewEventHandler()
        return EventListAppearanceSettingView(.init(setting.calendar))
            .environmentObject(viewAppearance)
            .environmentObject(handler)
    }
}
