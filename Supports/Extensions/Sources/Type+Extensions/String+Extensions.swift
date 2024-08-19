//
//  String+Extensions.swift
//  Extensions
//
//  Created by sudo.park on 2023/08/27.
//

import Foundation


// MARK: - localizing

extension Bundle {
    
    private final class Resource { }
    
    static var thisBundle: Bundle {
        return Bundle(for: Resource.self)
    }
}

public enum R {
    public typealias String = ExtensionsStrings
}

extension String {
    
    public func localized() -> String {
        
        return NSLocalizedString(
            self, 
            bundle: Bundle.thisBundle, 
            comment: ""
        )
    }
    
    public func localized(with args: any CVarArg...) -> String {
        let format = self.localized()
        return String(format: format, arguments: args)
    }
    
    public func formed(with args: any CVarArg...) -> String {
        return String(format: self, arguments: args)
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
        let checkIsValid = (try? self.isValidURL(path)) ?? true
        return checkIsValid ? URL(string: path) : nil
    }
    
    public func isValidURL(_ urlString: String) throws -> Bool {
        let pattern = #"^(https?|ftp)://[^\s/$.?#].[^\s]*$"#
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: urlString.utf16.count)
        return regex.firstMatch(in: urlString, options: [], range: range) != nil
    }
}


// MARK: - else

extension String {
    
    public static var randomEmoji: String {
        let emojis = 0x1F300...0x1F3F0
        let selected = emojis.randomElement()
            .flatMap { UnicodeScalar($0) }
            .flatMap { String($0) }
        return selected ?? "🙌"
    }
}

extension Array where Element == String {
    
    public func andJoin(
        seperator: String = ", ",
        lastSeperator: String = R.String.commonAnd
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
