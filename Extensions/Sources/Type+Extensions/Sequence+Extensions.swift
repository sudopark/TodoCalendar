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
