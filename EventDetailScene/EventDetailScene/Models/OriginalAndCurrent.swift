//
//  OriginalAndCurrent.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/6/23.
//

import Foundation


struct OriginalAndCurrent<T> {
    
    var origin: T
    var current: T
    
    init(origin: T, current: T? = nil) {
        self.origin = origin
        self.current = current ?? origin
    }
}

extension OriginalAndCurrent where T: Equatable {
    
    var isChanged: Bool {
        return origin != current
    }
}
