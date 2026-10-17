//
//  E2EFixture.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import Foundation


// 번들 조회에 Bundle(for:) 를 써야 해 class 다
final class E2EFixture {
    
    func holidaysJSON(named name: String, on day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return self.template(resource: "holidays")
            .replacingOccurrences(of: "{{NAME}}", with: name)
            .replacingOccurrences(of: "{{DATE}}", with: formatter.string(from: day))
    }
    
    private func template(resource: String) -> String {
        guard let url = Bundle(for: Self.self).url(forResource: resource, withExtension: "json"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            preconditionFailure("e2e fixture not found in runner bundle: \(resource).json")
        }
        return text
    }
}
