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
}
