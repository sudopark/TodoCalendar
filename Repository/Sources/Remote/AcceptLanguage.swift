//
//  AcceptLanguage.swift
//  Repository
//
//  Created by sudo.park on 5/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum AcceptLanguage {

    public static func headerValue(from preferredLanguages: [String]) -> String {
        guard !preferredLanguages.isEmpty else { return "en" }
        return preferredLanguages.enumerated()
            .map { index, language in
                guard index > 0 else { return language }
                let quality = max(0.1, 1.0 - Double(index) * 0.1)
                return "\(language);q=\(String(format: "%.1f", quality))"
            }
            .joined(separator: ",")
    }
}
