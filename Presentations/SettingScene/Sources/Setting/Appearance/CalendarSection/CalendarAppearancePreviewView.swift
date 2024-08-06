//
//  CalendarSectionAppearanceSettingView.swift
//  SettingScene
//
//  Created by sudo.park on 12/8/23.
//

import SwiftUI
import Domain
import Combine
import CommonPresentation


final class CalendarSectionAppearanceSettingViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var calendarModel: CalendarAppearanceModel = .init([], [])
    @Published var accentDays: [AccentDays: Bool] = [:]
    @Published var showUnderLine: Bool = false
    @Published var selectedWeekDay: DayOfWeeks = .sunday
    @Published var selectedColorTheme: ColorThemeModel = .init(.systemTheme)
    private var didFirstCalendarModelUpdated = false
    
    init(_ setting: CalendarSectionAppearanceSetting) {
        self.accentDays = setting.accnetDayPolicy
        self.showUnderLine = setting.showUnderLineOnEventDay
    }
    
    func bind(_ viewModel: any CalendarSectionAppearnaceSettingViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.currentWeekStartDay
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] day in
                self?.selectedWeekDay = day
            })
            .store(in: &self.cancellables)
        
        viewModel.calendarAppearanceModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                if self?.didFirstCalendarModelUpdated == true {
                    withAnimation {
                        self?.calendarModel = model
                    }
                } else {
                    self?.calendarModel = model
                    self?.didFirstCalendarModelUpdated = true
                }
            })
            .store(in: &self.cancellables)
        
        viewModel.accentDaysActivatedMap
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] map in
                self?.accentDays = map
            })
            .store(in: &self.cancellables)
        
        viewModel.isShowUnderLineOnEventDay
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.showUnderLine = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedColorTheme
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.selectedColorTheme = model
            })
            .store(in: &self.cancellables)
    }
}


final class CalendarSectionAppearanceSettingViewEventHandler: ObservableObject {
    
    var onAppear: () -> Void = { }
    var weekStartDaySelected: (DayOfWeeks) -> Void = { _ in }
    var changeColorTheme: () -> Void = { }
    var toggleAccentDay: (AccentDays) -> Void = { _ in }
    var toggleShowUnderline: (Bool) -> Void = { _ in }
}

// MARK: - CalendarAppearanceSampleView

struct CalendarAppearanceSampleView: View {
    
    @Binding private var model: CalendarAppearanceModel
    @EnvironmentObject private var appearance: ViewAppearance
    
    init(model: Binding<CalendarAppearanceModel>) {
        self._model = model
    }
    
    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("MARCH".localized())
                    .font(self.appearance.fontSet.size(12, weight: .semibold).asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                Grid(alignment: .center, horizontalSpacing: 4, verticalSpacing: 5) {
                    GridRow {
                        ForEach(model.weekDays, id: \.rawValue) { day in
                            textView(
                                day.veryShortText,
                                accent: day == .sunday ? .sunday : day == .saturday ? .saturday : nil
                            )
                        }
                    }
                    
                    ForEach(0..<model.weeks.count, id: \.self) { index in
                        GridRow {
                            ForEach(0..<model.weeks[index].count, id: \.self) { numberIndex in
                                dayTextView(model.weeks[index][numberIndex])
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(self.appearance.colorSet.dayBackground.asColor)
                    .shadow(
                        color: appearance.colorSet.text0.withAlphaComponent(0.4).asColor,
                        radius: 10
                    )
            )
            Spacer()
        }
        .padding(.bottom, 18)
    }
    
    private func dayTextView(_ day: CalendarAppearanceModel.DayModel?) -> some View {
        let text = day.map { "\($0.number)" } ?? ""
        return textView(
            text,
            accent: day?.accent,
            hasEvent: day?.hasEvent == true,
            isSelected: day?.number == 1
        )
    }
    
    private func textView(
        _ text: String,
        accent: AccentDays?,
        hasEvent: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        let textColor: UIColor = {
            if isSelected {
                return self.appearance.colorSet.selectedDayText
            } else {
                return self.appearance.accentCalendarDayColor(accent)
            }
        }()
        
        return ZStack {
            Text(text)
                .font(self.appearance.fontSet.size(10).asFont)
                .foregroundStyle(textColor.asColor)
            
            if hasEvent && self.appearance.showUnderLineOnEventDay {
                VStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(self.appearance.colorSet.eventText.asColor)
                        .frame(height: 0.5)
                        .padding(.horizontal, 2.5)
                        .padding(.vertical, 1)
                }
            }
        }
        .frame(width: 15, height: 16)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? self.appearance.colorSet.selectedDayBackground.asColor : self.appearance.colorSet.dayBackground.asColor)
        )
    }
}


// MARK: - CalendarSectionView

struct CalendarSectionAppearanceSettingView: View {
    
    @StateObject private var state: CalendarSectionAppearanceSettingViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: CalendarSectionAppearanceSettingViewEventHandler
    @Environment(\.colorScheme) var colorScheme
    
    var stateBinding: (CalendarSectionAppearanceSettingViewState) -> Void = { _ in }
    
    private let selectWeekDaySource: [DayOfWeeks] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]
    
    init(_ setting: CalendarSectionAppearanceSetting) {
        _state = .init(wrappedValue: .init(setting))
    }
    
    var body: some View {
        
        VStack {
            CalendarAppearanceSampleView(model: $state.calendarModel)
            
            VStack(spacing: 8) {
                AppearanceRow("Start day of week".localized(), pickerView)
                    .onReceive(state.$selectedWeekDay, perform: eventHandlers.weekStartDaySelected)
                
                AppearanceRow("Accent days".localized(), HStack {
                    accentDayView(.holiday)
                    accentDayView(.saturday)
                    accentDayView(.sunday)
                })
                
                AppearanceRow("Color theme".localized(), colorThemePreview)
                    .onTapGesture(perform: eventHandlers.changeColorTheme)
                
                AppearanceRow("Underline scheduled days".localized(), subTitle: "Widget".localized(), showUnderlineView)
                    .onReceive(state.$showUnderLine, perform: eventHandlers.toggleShowUnderline)
            }
        }
        .padding(.top, 20)
        .onAppear {
            self.stateBinding(self.state)
            self.eventHandlers.onAppear()
        }
    }
}


// MARK: - CalendarSectionView startWeekday

extension CalendarSectionAppearanceSettingView {
    
    private var pickerView: some View {
        Menu {
            Picker(selection: $state.selectedWeekDay) {
                ForEach(selectWeekDaySource, id: \.self) { day in
                    HStack {
                        if day == state.selectedWeekDay {
                            Image(systemName: "checkmark")
                                .font(appearance.fontSet.normal.asFont)
                                .foregroundStyle(appearance.colorSet.text0.asColor)
                        }
                        Text(day.text)
                            .font(appearance.fontSet.normal.asFont)
                            .foregroundStyle(appearance.colorSet.text0.asColor)
                    }
                }
            } label: {
                EmptyView()
            }
        } label: {
            HStack(spacing: 4) {
                Text(state.selectedWeekDay.text)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text2.asColor)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.text2.asColor)
            }
        }
    }
    
    private func accentDayView(_ day: AccentDays) -> some View {
        let isOn = state.accentDays[day] ?? false
        let textColor: UIColor = isOn
            ? self.appearance.colorSet.text0_inverted
            : self.appearance.colorSet.text2
        let lineColor: UIColor = isOn
            ? .clear
            : self.appearance.colorSet.text2
        let backgroundColor: UIColor = isOn
            ? self.appearance.colorSet.text0
            : .clear
        
        return Text(day.text)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .font(self.appearance.fontSet.size(10).asFont)
            .foregroundStyle(textColor.asColor)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor.asColor)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(lineColor.asColor, lineWidth: 1)
            }
            .onTapGesture {
                eventHandlers.toggleAccentDay(day)
            }
    }
    
    private var colorThemePreview: some View {
        HStack {
            
            ColorThemePreviewView(
                model: self.state.selectedColorTheme,
                metric: .init(fontSize: 15, circleSize: 4, circlePadding: 6),
                isSystemDark: colorScheme == .dark
            )
            .frame(width: 40, height: 40)
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
    }
    
    private var showUnderlineView: some View {
        Toggle("", isOn: $state.showUnderLine)
            .controlSize(.small)
            .labelsHidden()
    }
}


private extension AccentDays {
    
    var text: String {
        switch self {
        case .holiday: return "Holiday".localized()
        case .saturday: return "Saturday".localized()
        case .sunday: return "Sunday".localized()
        }
    }
}

private struct SmallToggleStyle: ToggleStyle {
    
    @EnvironmentObject private var appearance: ViewAppearance
    
    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: configuration.isOn ? "checkmark.square" : "square")
            .resizable()
            .frame(width: 22, height: 22)
            .onTapGesture { configuration.isOn.toggle() }
    }
}
