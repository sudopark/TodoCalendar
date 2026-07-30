//
//  Array+Extension.swift
//  Extensions
//
//  Created by sudo.park on 2023/03/31.
//

import Foundation

extension Sequence {
    
    public func asDictionary<Key: Hashable>(_ keySelector: (Element) -> Key) -> [Key: Element] {
        return self.reduce(into: [Key: Element]()) { $0[keySelector($1)] = $1 }
    }

    /// key 기준 중복 제거 — 같은 key의 **첫** 원소만 남기고 순서를 유지한다.
    /// (`asDictionary`는 마지막 원소가 남고 순서를 잃는다.)
    public func removeDuplicates<Key: Hashable>(_ keySelector: (Element) -> Key) -> [Element] {
        return self
            .reduce(into: (seen: Set<Key>(), result: [Element]())) { acc, element in
                guard acc.seen.insert(keySelector(element)).inserted else { return }
                acc.result.append(element)
            }
            .result
    }

    public func asyncForEach(_ asyncTask: (Element) async throws -> Void) async rethrows {
        
        for element in self {
            try await asyncTask(element)
        }
    }
}


extension Array {
    
    public subscript(safe index: Int) -> Element? {
        get {
            guard (0..<self.count) ~= index else { return nil }
            return self[index]
        }
    }
}
