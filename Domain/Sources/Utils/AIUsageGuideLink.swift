//
//  AIUsageGuideLink.swift
//  Domain
//
//  Created by sudo.park on 8/6/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum AIUsageGuideLink {

    public static let koPath = HelpLink.koPath
    public static let enPath = HelpLink.enPath

    public static var currentPath: String {
        let isKorean = Locale.current.language.languageCode == .korean
        return isKorean ? self.koPath : self.enPath
    }
}
