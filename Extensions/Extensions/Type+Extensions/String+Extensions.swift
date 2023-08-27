//
//  String+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/08/27.
//

import Foundation


extension String {
    
    public func localized() -> String {
        
        return NSLocalizedString(self, bundle: Bundle.main, comment: "")
    }
    
    public func localized(with args: CVarArg...) -> String {
        let format = self.localized()
        return String(format: format, arguments: args)
    }
}
