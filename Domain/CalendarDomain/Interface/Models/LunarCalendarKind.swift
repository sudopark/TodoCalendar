//
//  LunarCalendarKind.swift
//  CalendarDomainInterface
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics


public enum LunarCalendarKind: Sendable, Equatable {
    case chinese
    case dangi
    case vietnamese

    public init(language: Locale.LanguageCode?) {
        switch language {
        case .korean?, .japanese?: self = .dangi
        case .vietnamese?: self = .vietnamese
        default: self = .chinese
        }
    }

    public func calendar(timeZone: TimeZone) -> Calendar {
        return Calendar(identifier: self.availableIdentifier) |> \.timeZone .~ timeZone
    }

    private var availableIdentifier: Calendar.Identifier {
        guard #available(iOS 26, *) else { return .chinese }
        switch self {
        case .chinese: return .chinese
        case .dangi: return .dangi
        case .vietnamese: return .vietnamese
        }
    }
}
