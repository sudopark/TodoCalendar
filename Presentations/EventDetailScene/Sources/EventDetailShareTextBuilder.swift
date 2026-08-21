//
//  EventDetailShareTextBuilder.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Extensions
import CommonPresentation


enum EventDetailShareTagLine: Equatable {
    case eventTag(String)
    case googleCalendar(String)
    case appleCalendar(String)

    private enum Constant {
        static let serviceNameSeparator: String = " - "
    }

    var labelKey: String {
        switch self {
        case .eventTag: return "eventTag.title"
        case .googleCalendar, .appleCalendar: return "event_detail::share::field::calendar"
        }
    }

    var name: String {
        guard let serviceNameKey else { return self.calendarName }
        return [serviceNameKey.localized(), self.calendarName].joined(separator: Constant.serviceNameSeparator)
    }

    private var serviceNameKey: String? {
        switch self {
        case .eventTag: return nil
        case .googleCalendar: return "event_setting::external_calendar::google::serviceName"
        case .appleCalendar: return "event_setting::external_calendar::apple::serviceName"
        }
    }

    private var calendarName: String {
        switch self {
        case .eventTag(let name), .googleCalendar(let name), .appleCalendar(let name):
            return name
        }
    }
}

struct EventDetailShareModel: Equatable {
    let name: String
    var isTodo: Bool = false
    var timeText: String?
    var repeatText: String?
    var tagLine: EventDetailShareTagLine?
    var placeName: String?
    var url: String?
    var memo: String?
}

struct EventDetailShareTextBuilder {

    private enum Constant {
        static let labelSeparator: String = ": "
        static let todoTextKey: String = "calendar::event_time::todo"
        static let periodSeparator: String = " ~ "
        static let lineSeparator: String = "\n"
        static let allDayTextKey: String = "calendar::event_time::allday"
    }

    func build(_ model: EventDetailShareModel) -> String {
        let fields: [(labelKey: String, value: String?)] = [
            ("event_detail::share::field::time", model.timeText),
            ("event_detail::share::field::repeating", model.repeatText)
        ]
        + self.tagFields(model.tagLine)
        + [
            ("event_detail::share::field::place", model.placeName),
            ("event_detail::share::field::url", model.url),
            ("event_detail::share::field::memo", model.memo)
        ]
        let fieldLines = fields.compactMap { field in
            field.value.map { "\(field.labelKey.localized())\(Constant.labelSeparator)\($0)" }
        }
        return ([self.nameLine(model)] + fieldLines).joined(separator: Constant.lineSeparator)
    }

    private func tagFields(_ line: EventDetailShareTagLine?) -> [(labelKey: String, value: String?)] {
        guard let line else { return [] }
        return [(line.labelKey, line.name)]
    }

    private func nameLine(_ model: EventDetailShareModel) -> String {
        guard model.isTodo else { return model.name }
        return "(\(Constant.todoTextKey.localized())) \(model.name)"
    }

    func timeText(from selectedTime: SelectedTime) -> String {
        switch selectedTime {
        case .at(let time):
            return self.joinedParts(time)

        case .period(let start, let end) where start.day == end.day:
            return [self.joinedParts(start), end.time ?? ""]
                .joined(separator: Constant.periodSeparator)

        case .period(let start, let end):
            return [self.joinedParts(start), self.joinedParts(end)]
                .joined(separator: Constant.periodSeparator)

        case .singleAllDay(let time):
            return [self.joinedParts(time), Constant.allDayTextKey.localized()]
                .joined(separator: " ")

        case .alldayPeriod(let start, let end):
            let period = [self.joinedParts(start), self.joinedParts(end)]
                .joined(separator: Constant.periodSeparator)
            return [period, Constant.allDayTextKey.localized()]
                .joined(separator: " ")
        }
    }

    private func joinedParts(_ text: SelectTimeText) -> String {
        return [text.year, text.day, text.time]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
