//
//  CalendarAppearancePreviewView.swift
//  SettingScene
//
//  Created by sudo.park on 12/8/23.
//

import SwiftUI
import Domain
import Combine
import CommonPresentation


// MARK: - CalendarAppearancePreviewView

struct CalendarAppearancePreviewView: View {
    
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
                    .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                Grid(alignment: .center, horizontalSpacing: 4, verticalSpacing: 5) {
                    GridRow {
                        ForEach(model.weekDays, id: \.rawValue) { day in
                            textView(day.veryShortText, isWeekEnd: day == .sunday || day == .saturday)
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
                    .shadow(radius: 10)
            )
            Spacer()
        }
        .padding(.bottom, 18)
    }
    
    private func dayTextView(_ day: CalendarAppearanceModel.DayModel?) -> some View {
        let text = day.map { "\($0.number)" } ?? ""
        return textView(
            text,
            isWeekEnd: day?.isWeekEnd == true,
            isHoliday: day?.isHoliday == true,
            hasEvent: day?.hasEvent == true,
            isSelected: day?.number == 1
        )
    }
    
    private func textView(
        _ text: String,
        isWeekEnd: Bool,
        isHoliday: Bool = false,
        hasEvent: Bool = false,
        isSelected: Bool = false
    ) -> some View {
        let textColor: UIColor = {
            if isSelected {
                return self.appearance.colorSet.selectedDayText
            } else if isHoliday {
                return self.appearance.colorSet.holidayText
            } else if isWeekEnd {
                return self.appearance.colorSet.weekEndText
            } else  {
                return self.appearance.colorSet.normalText
            }
        }()
        
        return ZStack {
            Text(text)
                .font(self.appearance.fontSet.size(10).asFont)
                .foregroundStyle(textColor.asColor)
            
            if hasEvent {
                VStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(self.appearance.colorSet.event.asColor)
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

struct CalendarSectionView: View {
    
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var state: AppearanceSettingViewState
    @EnvironmentObject private var eventHandlers: AppearanceSettingViewEventHandler
    
    private let selectWeekDaySource: [DayOfWeeks] = [
        .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
    ]
    
    init() { }
    
    var body: some View {
        Section(header: CalendarAppearancePreviewView(model: $state.calendarModel)) {
            
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
        .padding(.horizontal, 16)
    }
}


// MARK: - CalendarSectionView startWeekday

extension CalendarSectionView {
    
    private var pickerView: some View {
        Menu {
            Picker(selection: $state.selectedWeekDay) {
                ForEach(selectWeekDaySource, id: \.self) { day in
                    HStack {
                        if day == state.selectedWeekDay {
                            Image(systemName: "checkmark")
                                .font(appearance.fontSet.normal.asFont)
                                .foregroundStyle(appearance.colorSet.normalText.asColor)
                        }
                        Text(day.text)
                            .font(appearance.fontSet.normal.asFont)
                            .foregroundStyle(appearance.colorSet.normalText.asColor)
                    }
                }
            } label: {
                EmptyView()
            }
        } label: {
            HStack(spacing: 4) {
                Text(state.selectedWeekDay.text)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
            }
        }
    }
    
    private func accentDayView(_ day: AccentDays) -> some View {
        let isOn = state.accentDays[day] ?? false
        let textColor: UIColor = isOn
            ? self.appearance.colorSet.white
            : self.appearance.colorSet.subSubNormalText
        let lineColor: UIColor = isOn
            ? .clear
            : self.appearance.colorSet.subSubNormalText
        let backgroundColor: UIColor = isOn
            ? self.appearance.colorSet.normalText
            : .clear
        
        return Button {
            self.eventHandlers.toggleAccentDay(day)
        } label: {
            Text(day.text)
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
        }
    }
    
    private var colorThemePreview: some View {
        HStack {
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.subSubNormalText.asColor)
        }
    }
    
    private var showUnderlineView: some View {
        Toggle("", isOn: $state.showUnderLine)
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
