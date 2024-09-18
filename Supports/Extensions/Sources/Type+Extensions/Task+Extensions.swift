//
//  Task+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/06/30.
//

import Foundation
import Combine

extension Task: Cancellable { }

extension Task {
    
    public func store(in set: inout Set<AnyCancellable>) {
        
        let anyCancellable = AnyCancellable(self)
        set.insert(anyCancellable)
    }
}
