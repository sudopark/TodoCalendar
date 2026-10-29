//
//  Dummies.swift
//  TestDoubles
//
//  Created by sudo.park on 2023/07/02.
//

import Foundation
import Domain


extension TimeInterval {
    
    public static func range(from: String, to: String, in timeZone: TimeZone) throws -> Range<TimeInterval> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = timeZone
        
        let start = try formatter.date(from: from).unwrap()
        let end = try formatter.date(from: to).unwrap()
        return (start.timeIntervalSince1970..<end.timeIntervalSince1970)
    }
}

extension TodoEvent {
    
    public static func dummy(_ int: Int = 0) -> TodoEvent {
        return .init(uuid: "id:\(int)", name: "name:\(int)")
    }
}

extension DoneTodoEvent {
    
    public static func dummy(_ int: Int = 0) -> DoneTodoEvent {
        return .init(uuid: "did:\(int)", name: "name:\(int)", originEventId: "id:\(int)", doneTime: .now)
    }
}


extension AppThemeColorSetKey {

    public static let snapshotRepresentatives: [AppThemeColorSetKey] = [
        .tomato, .ruby, .crimson, .midnight, .ink, .abyss
    ]
}
