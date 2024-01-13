//
//  EventNotificationTimeOption+Mapping.swift
//  Repository
//
//  Created by sudo.park on 1/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


extension EventNotificationTimeOption {
    
    var asString: String {
        switch self {
        case .atTime: return "atTime"
        case .before(let seconds): return "before-\(seconds)"
        case .allDay9AM: return "allDay9AM"
        case .allDay12AM: return "allDay12AM"
        case .allDay9AMBefore(let seconds): return "allDay9AMBefore-\(seconds)"
        }
    }
    
    init?(from string: String) {
        let compos = string.components(separatedBy: "-")
        switch compos.first {
        case "atTime":
            self = .atTime
            
        case "before":
            guard let seconds = compos.last.flatMap ({ TimeInterval($0) })
            else { return nil }
            self = .before(seconds: seconds)
            
        case "allDay9AM":
            self = .allDay9AM
            
        case "allDay12AM":
            self = .allDay12AM
            
        case "allDay9AMBefore":
            guard let seconds = compos.last.flatMap ({ TimeInterval($0) })
            else { return nil }
            self = .allDay9AMBefore(seconds: seconds)
            
        default: return nil
        }
    }
}
