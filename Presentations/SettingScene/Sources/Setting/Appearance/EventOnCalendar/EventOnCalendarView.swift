//
//  EventOnCalendarView.swift
//  SettingScene
//
//  Created by sudo.park on 12/16/23.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


final class EventOnCalendarViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var additionalFontSizeModel: EventTextAdditionalSizeModel = .init(0)
    @Published var isBold: Bool = false
    @Published var isShowEventTagColor: Bool = false
    
    init(_ setting: EventOnCalendarAppearanceSetting) {
        self.additionalFontSizeModel = .init(setting.eventOnCalenarTextAdditionalSize)
        self.isBold = setting.eventOnCalendarIsBold
        self.isShowEventTagColor = setting.eventOnCalendarShowEventTagColor
    }
    
    func bind(_ viewModel: any EventOnCalendarViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind
        viewModel.textIncreasedSizeText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.additionalFontSizeModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.isBoldTextOnCalendar
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isBold in
                self?.isBold = isBold
            })
            .store(in: &self.cancellables)
        
        viewModel.showEvnetTagColor
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isShow in
                self?.isShowEventTagColor = isShow
            })
            .store(in: &self.cancellables)
    }
}

final class EventOnCalendarViewEventHandler: ObservableObject {
    
    var onAppear: () -> Void = { }
    var increaseFontSize: () -> Void = { }
    var decreaseFontSize: () -> Void = { }
    var toggleIsBold: (Bool) -> Void = { _ in }
    var toggleShowEventTagColor: (Bool) -> Void = { _ in }
}

struct EventOnCalendarViewPreviewView: View {
    
    @EnvironmentObject private var appearance: ViewAppearance
    
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text("1")
                    .font(appearance.fontSet.day.asFont)
                    .foregroundStyle(appearance.colorSet.weekDayText.asColor)
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EventTagColor.holiday.colorForEventOnCalendar(appearance).asColor)
                        .frame(width: 3, height: 12)
                        .padding(.leading, 1)
                    
                    Text("All day".localized())
                        .font(appearance.eventTextFontOnCalendar().asFont)
                        .foregroundStyle(appearance.colorSet.event.asColor)
                        .lineLimit(1)
                }
                .frame(width: 52, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(EventTagColor.holiday.colorForEventOnCalendar(appearance).asColor)
                )
                
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(EventTagColor.default.colorForEventOnCalendar(appearance).asColor)
                        .frame(width: 3, height: 12)
                        .padding(.leading, 1)
                    
                    Text("Some time".localized())
                        .font(appearance.eventTextFontOnCalendar().asFont)
                        .foregroundStyle(appearance.colorSet.event.asColor)
                        .lineLimit(1)
                }
                .frame(width: 52, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(self.appearance.colorSet.dayBackground.asColor)
                    .shadow(radius: 10)
            )
            Spacer()
        }
        .padding(.bottom, 18)
    }
}

struct EventOnCalendarView: View {
    
    @StateObject private var state: EventOnCalendarViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandler: EventOnCalendarViewEventHandler
    
    var stateBinding: (EventOnCalendarViewState) -> Void = { _ in }
    
    init(_ setting: EventOnCalendarAppearanceSetting) {
        self._state = .init(wrappedValue: .init(setting))
    }
    
    var body: some View {
        VStack {
            EventOnCalendarViewPreviewView()
            
            VStack(spacing: 8) {
                AppearanceRow("Event font size".localized(), fontSizeSettingView)
                
                AppearanceRow("Bold text".localized(), boldTextView)
                    .onReceive(state.$isBold, perform: eventHandler.toggleIsBold)
                
                AppearanceRow("Event color".localized(), showEventTagColorView)
                    .onReceive(state.$isShowEventTagColor, perform: eventHandler.toggleShowEventTagColor)
            }
        }
        .padding(.top, 20)
        .onAppear {
            self.stateBinding(self.state)
            self.eventHandler.onAppear()
        }
    }
    
    private var fontSizeSettingView: some View {
        HStack(spacing: 8) {
            
            Text(state.additionalFontSizeModel.sizeText)
                .font(appearance.fontSet.size(12).asFont)
                .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
            
            HStack(spacing: 2) {
                
                Button {
                    eventHandler.decreaseFontSize()
                } label: {
                    Text("-")
                        .font(appearance.fontSet.normal.asFont)
                        .foregroundStyle(appearance.colorSet.normalText.asColor)
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
                        .foregroundStyle(appearance.colorSet.normalText.asColor)
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
    
    private var boldTextView: some View {
        Toggle("", isOn: $state.isBold)
            .labelsHidden()
    }
    
    private var showEventTagColorView: some View {
        Toggle("", isOn: $state.isShowEventTagColor)
            .labelsHidden()
    }
}


// MARK: - preview view


struct EventOnCalendarViewPreviewProvider: PreviewProvider {
    
    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        viewAppearance.eventOnCalenarTextAdditionalSize = -2
        
        let eventHandler = EventOnCalendarViewEventHandler()
        return EventOnCalendarView(.init(setting.calendar))
            .eventHandler(\.stateBinding) { state in
                state.additionalFontSizeModel = .init(0)
                state.isBold = false
                state.isShowEventTagColor = true
            }
            .environmentObject(viewAppearance)
            .environmentObject(eventHandler)
    }
}
