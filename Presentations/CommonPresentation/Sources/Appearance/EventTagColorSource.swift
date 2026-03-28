//
//  EventTagColorSource.swift
//  CommonPresentation
//
//  Created by sudo.park on 2026/03/10.
//

import Domain


// MARK: - EventTagColorSource

/// 이벤트 태그 색상 결정에 필요한 정보를 제공하는 마커 프로토콜.
/// 구체 타입별로 색상 결정 로직이 달라지며, EventTagColorView 내부에서 타입으로 분기.
public protocol EventTagColorSource: Sendable { }


// MARK: - EventTagId conformance

/// 일반 태그(holiday / default / custom)는 EventTagId 자체를 소스로 사용
extension EventTagId: EventTagColorSource { }


// MARK: - Google Calendar event color source

/// Google Calendar 이벤트 전용 색상 소스.
/// calendarId(= EventTagId에 인코딩된 값)와 event-specific colorId를 함께 보유.
public struct GoogleCalendarEventColorSource: EventTagColorSource {

    public let calendarId: String
    public let colorId: String?

    public init(calendarId: String, colorId: String?) {
        self.calendarId = calendarId
        self.colorId = colorId
    }
}
