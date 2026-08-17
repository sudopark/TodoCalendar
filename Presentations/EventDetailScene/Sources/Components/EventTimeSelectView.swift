//
//  EventTimeSelectView.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import CommonPresentation


// MARK: - EventTimeSelectView

struct EventTimeSelectView: View {

    @Environment(ViewAppearance.self) private var appearance

    enum TimeSelecting {
        case start
        case end

        var title: String {
            switch self {
            case .start: return "calendar::event_time::start".localized()
            case .end: return "calendar::event_time::end".localized()
            }
        }
    }
    @State private var isTimeSelecting: TimeSelecting?

    let time: SelectedTime?
    var onSelectStartTime: (Date) -> Void = { _ in }
    var onSelectEndTime: (Date) -> Void = { _ in }
    var onToggleAllDay: () -> Void = { }
    var onBeginSelecting: () -> Void = { }

    var body: some View {
        VStack(spacing: Metric.Spacing.small) {
            HStack(spacing: Metric.Spacing.large) {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(appearance.colorSet.text1.asColor)

                self.selectedTimeView()

                Spacer()

                self.toggleAllDayView
            }

            if let selecting = self.isTimeSelecting {
                self.timePickerView(selecting)
            }
        }
    }

    private func selectedTimeView() -> some View {
        guard let time = self.time else {
            return EmptyView().asAnyView()
        }
        let isInvalid = time.isValid == false
        switch time {
        case .period(let start, let end), .alldayPeriod(let start, let end):
            return HStack(spacing: Metric.Spacing.large) {
                self.timeView(start, .start, isInvalid: isInvalid)
                Image(systemName: "chevron.right")
                    .foregroundStyle(appearance.colorSet.text1.asColor)
                self.timeView(end, .end, isInvalid: isInvalid)
            }
            .asAnyView()

        case .singleAllDay(let day):
            return HStack(spacing: Metric.Spacing.large) {
                self.timeView(day, .start, isInvalid: isInvalid)
                Spacer()
            }
            .asAnyView()

        case .at(let day):
            return self.timeView(day, .start, isInvalid: isInvalid).asAnyView()
        }
    }

    private func timeView(
        _ text: SelectTimeText, _ position: TimeSelecting, isInvalid: Bool
    ) -> some View {
        let isSelecting = self.isTimeSelecting == position
        let textColor = isSelecting ? appearance.colorSet.text1.asColor : appearance.colorSet.text0.asColor
        return EventTimeTextView(text, textColor: textColor, isStrikethrough: isInvalid)
            .onTapGesture {
                self.appearance.impactIfNeed()
                self.updateTimePickerShowing(position)
            }
    }

    private func updateTimePickerShowing(_ selecting: TimeSelecting) {
        appearance.withAnimationIfNeed {
            self.isTimeSelecting = self.isTimeSelecting == selecting ? nil : selecting
        }
        self.onBeginSelecting()
    }

    private var toggleAllDayView: some View {
        let isAllDay = time?.isAllDay ?? false
        return Button {
            onToggleAllDay()
        } label: {
            Text("calendar::event_time::allday".localized())
                .foregroundStyle(
                    isAllDay ? appearance.colorSet.selectedDayText.asColor : appearance.colorSet.text2.asColor
                )
                .padding(.vertical, spacing: .small)
                .padding(.horizontal, spacing: .large)
        }
        .background(self.toggleAllDayBackgroundView(isAllDay))
    }

    private func toggleAllDayBackgroundView(_ isAllDay: Bool) -> some View {
        Group {
            if isAllDay {
                RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                    .fill(appearance.colorSet.selectedDayBackground.asColor)
            } else {
                RoundedRectangle(cornerRadius: Metric.Radius.sheet)
                    .stroke(appearance.colorSet.text2.asColor, lineWidth: 1)
            }
        }
    }

    private func timePickerView(_ selecting: TimeSelecting) -> some View {
        let isAllDay = time?.isAllDay ?? false
        let binding = Binding<Date>(
            get: {
                switch selecting {
                case .start: return time?.startDate ?? Date()
                case .end: return time?.endDate ?? Date()
                }
            },
            set: { newDate in
                switch selecting {
                case .start: onSelectStartTime(newDate)
                case .end: onSelectEndTime(newDate)
                }
            }
        )
        return VStack(alignment: .leading, spacing: Metric.Spacing.xsmall) {
            Text(selecting.title)
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text1.asColor)

            DatePicker(
                "", selection: binding,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .invertColorIfNeed(appearance)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


private extension SelectedTime {

    var startDate: Date {
        switch self {
        case .at(let time): return time.date
        case .singleAllDay(let time): return time.date
        case .period(let start, _): return start.date
        case .alldayPeriod(let start, _): return start.date
        }
    }

    var endDate: Date? {
        switch self {
        case .period(_, let end): return end.date
        case .alldayPeriod(_, let end): return end.date
        default: return nil
        }
    }
}
