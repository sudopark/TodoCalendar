//
//  LegalLink.swift
//  Domain
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

public enum LegalLink {

    public static var termsPath: String { self.documentPath("terms") }
    public static var privacyPolicyPath: String { self.documentPath("privacy") }

    private static func documentPath(_ document: String) -> String {
        let language = Locale.isCurrentKorean ? "ko" : "en"
        return "https://todo-calendar.com/\(document)/\(language)"
    }
}
