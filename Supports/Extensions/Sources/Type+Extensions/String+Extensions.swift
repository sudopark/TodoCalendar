//
//  String+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/08/27.
//

import Foundation


// MARK: - localizing

extension String {
    
    public func localized() -> String {
        
        return NSLocalizedString(self, bundle: Bundle.main, comment: "")
    }
    
    public func localized(with args: any CVarArg...) -> String {
        let format = self.localized()
        return String(format: format, arguments: args)
    }
}


// MARK: - encoding

extension String {
    
    public func isEscaped() -> Bool {
        return self.removingPercentEncoding != self
    }
    
    public func asURL(withEncoding allowCharSet: CharacterSet = .urlQueryAllowed) -> URL? {
        let path = self.isEscaped()
            ? self
            : self.addingPercentEncoding(withAllowedCharacters: allowCharSet) ?? self
        return URL(string: path)
    }
}


// MARK: - else

extension Array where Element == String {
    
    public func andJoin(
        seperator: String = ", ",
        lastSeperator: String = "and".localized()
    ) -> String {
        guard self.count > 1
        else {
            return self.first ?? ""
        }
        
        var elements = self; let last = elements.removeLast()
        let leading = elements.joined(separator: seperator)
        return "\(leading) \(lastSeperator) \(last)"
    }
}
