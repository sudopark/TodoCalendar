//
//  RemoteDateParser.swift
//  Repository
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


enum RemoteDateParser {

    static func parse(_ value: Any?) -> Date? {
        guard let iso = value as? String else { return nil }
        return self.date(from: iso, options: [.withInternetDateTime, .withFractionalSeconds])
            ?? self.date(from: iso, options: [.withInternetDateTime])
    }

    private static func date(
        from iso: String,
        options: ISO8601DateFormatter.Options
    ) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = options
        return formatter.date(from: iso)
    }
}
