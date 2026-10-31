//
//  SettingEndpoints.swift
//  SettingDomain
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import RemoteInfraInterface
import SettingDomainInterface


// MARK: - AppSetting

public enum AppSettingEndpoints: Endpoint {
    case defaultEventTagColor
    case colorThemes
    case colorTheme(uuid: String)
    
    public var host: EndpointHost {
        return .calendarAPI(path: "v2/setting")
    }
    
    public var subPath: String {
        switch self {
        case .defaultEventTagColor: return "event/tag/default/color"
        case .colorThemes: return "color_themes"
        case .colorTheme(let uuid): return "color_themes/\(uuid)"
        }
    }
    
    public var authorization: EndpointAuthorization {
        return .calendarAPI
    }
}
